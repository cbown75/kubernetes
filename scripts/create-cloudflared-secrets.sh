#!/bin/bash
# Simple Cloudflared sealed secret fix - just gets the job done

set -e

# Configuration
NAMESPACE="cloudflare-tunnel"
SECRET_NAME="cloudflare-tunnel-cloudflared"
OUTPUT_FILE="clusters/korriban/apps/cloudflared/sealed-secret.yaml"

echo "=== Cloudflared Sealed Secret Fix ==="
echo

# Get credentials
echo "Enter Cloudflare tunnel credentials:"
read -p "Account ID: " ACCOUNT_ID
read -p "Tunnel ID: " TUNNEL_ID
read -p "Tunnel Name: " TUNNEL_NAME
read -s -p "Tunnel Secret: " TUNNEL_SECRET
echo

# Validate inputs
if [[ -z "$ACCOUNT_ID" || -z "$TUNNEL_ID" || -z "$TUNNEL_NAME" || -z "$TUNNEL_SECRET" ]]; then
  echo "❌ Error: All fields are required"
  exit 1
fi

# Create temp files
TEMP_DIR=$(mktemp -d)
SECRET_FILE="$TEMP_DIR/secret.yaml"
SEALED_FILE="$TEMP_DIR/sealed.yaml"

# Clean up on exit
trap "rm -rf $TEMP_DIR" EXIT

echo "✅ Creating secret with proper structure..."

# Create the JSON credentials
CREDENTIALS_JSON=$(
  cat <<EOF
{
  "AccountTag": "$ACCOUNT_ID",
  "TunnelID": "$TUNNEL_ID",
  "TunnelName": "$TUNNEL_NAME",
  "TunnelSecret": "$TUNNEL_SECRET"
}
EOF
)

# Create the base secret
cat >"$SECRET_FILE" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: $SECRET_NAME
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: cloudflared
    app.kubernetes.io/part-of: cloudflare-tunnel
type: Opaque
stringData:
  credentials.json: |
$CREDENTIALS_JSON
EOF

echo "✅ Sealing secret..."

# Seal the secret
kubeseal -f "$SECRET_FILE" -w "$SEALED_FILE" \
  --controller-name=sealed-secrets \
  --controller-namespace=kube-system \
  --format yaml

# Check if template has type: Opaque
if ! grep -q "type: Opaque" "$SEALED_FILE"; then
  echo "⚠️  Adding missing type: Opaque to template..."

  # Create a fixed version
  cat >"$TEMP_DIR/fixed.yaml" <<'EOF'
# This will be replaced by the actual sealed secret
EOF

  # Copy everything up to template section
  sed '/^  template:/q' "$SEALED_FILE" >"$TEMP_DIR/fixed.yaml"

  # Add proper template
  cat >>"$TEMP_DIR/fixed.yaml" <<EOF
  template:
    type: Opaque
    metadata:
      name: $SECRET_NAME
      namespace: $NAMESPACE
      labels:
        app.kubernetes.io/name: cloudflared
        app.kubernetes.io/part-of: cloudflare-tunnel
EOF

  # Add any remaining content after template
  sed -n '/^  template:/,$p' "$SEALED_FILE" | sed '1,/^    metadata:/d' | sed '/^      name:/,$d' >>"$TEMP_DIR/fixed.yaml" 2>/dev/null || true

  mv "$TEMP_DIR/fixed.yaml" "$SEALED_FILE"
fi

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Copy to final location
cp "$SEALED_FILE" "$OUTPUT_FILE"

echo "✅ SUCCESS! Sealed secret updated: $OUTPUT_FILE"
echo

# Verify the fix
if grep -q "type: Opaque" "$OUTPUT_FILE"; then
  echo "✅ Verified: Template includes 'type: Opaque'"
else
  echo "❌ Warning: Template may still be missing 'type: Opaque'"
fi

echo
echo "Next steps:"
echo "  git add $OUTPUT_FILE"
echo "  git commit -m 'Fix Cloudflare tunnel sealed secret template'"
echo "  git push"
echo
echo "Then check the cloudflared logs after a few minutes."
