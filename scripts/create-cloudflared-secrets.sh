#!/bin/bash
# Simple Cloudflared sealed secret creator - creates properly formatted sealed secrets
# Run from the repository root: ./scripts/create-cloudflared-secrets.sh

set -e

# Configuration
NAMESPACE="cloudflare-tunnel"
SECRET_NAME="cloudflare-tunnel-cloudflared"
OUTPUT_FILE="apps/cloudflared/overlay/korriban/sealed-secrets.yaml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Cloudflared Sealed Secret Creator ===${NC}"
echo

# Check if we're in the right directory
if [ ! -d "apps/cloudflared" ]; then
  echo -e "${RED}❌ Error: Please run this script from the repository root${NC}"
  echo -e "${RED}Expected to find: apps/cloudflared/${NC}"
  exit 1
fi

# Check prerequisites
if ! command -v kubectl &>/dev/null; then
  echo -e "${RED}❌ kubectl not found${NC}"
  exit 1
fi

if ! command -v kubeseal &>/dev/null; then
  echo -e "${RED}❌ kubeseal not found${NC}"
  echo -e "${YELLOW}Install with: brew install kubeseal${NC}"
  exit 1
fi

# Get credentials
echo "Enter Cloudflare tunnel credentials:"
read -p "Account ID: " ACCOUNT_ID
read -p "Tunnel ID: " TUNNEL_ID
read -p "Tunnel Name: " TUNNEL_NAME
read -s -p "Tunnel Secret: " TUNNEL_SECRET
echo

# Validate inputs
if [[ -z "$ACCOUNT_ID" || -z "$TUNNEL_ID" || -z "$TUNNEL_NAME" || -z "$TUNNEL_SECRET" ]]; then
  echo -e "${RED}❌ Error: All fields are required${NC}"
  exit 1
fi

# Create temp files
TEMP_DIR=$(mktemp -d)
SECRET_FILE="$TEMP_DIR/secret.yaml"
SEALED_FILE="$TEMP_DIR/sealed.yaml"

# Clean up on exit
trap "rm -rf $TEMP_DIR" EXIT

echo -e "${GREEN}✅ Creating secret with proper structure...${NC}"

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

echo -e "${GREEN}✅ Sealing secret...${NC}"

# Seal the secret
kubeseal -f "$SECRET_FILE" -w "$SEALED_FILE" \
  --controller-name=sealed-secrets \
  --controller-namespace=kube-system \
  --format yaml

# Verify and fix template if needed
if ! grep -q "type: Opaque" "$SEALED_FILE"; then
  echo -e "${YELLOW}⚠️  Adding missing type: Opaque to template...${NC}"

  # Create a fixed version with proper template
  cat >"$TEMP_DIR/fixed.yaml" <<EOF
---
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: $SECRET_NAME
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: cloudflared
    app.kubernetes.io/part-of: cloudflare-tunnel
EOF

  # Add the encrypted data section
  sed -n '/^spec:/,/^  template:/p' "$SEALED_FILE" | sed '/^  template:/d' >>"$TEMP_DIR/fixed.yaml"

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

  mv "$TEMP_DIR/fixed.yaml" "$SEALED_FILE"
fi

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Copy to final location
cp "$SEALED_FILE" "$OUTPUT_FILE"

echo -e "${GREEN}✅ SUCCESS! Sealed secret created: $OUTPUT_FILE${NC}"
echo

# Verify the fix
if grep -q "type: Opaque" "$OUTPUT_FILE"; then
  echo -e "${GREEN}✅ Verified: Template includes 'type: Opaque'${NC}"
else
  echo -e "${YELLOW}⚠️  Warning: Template may still be missing 'type: Opaque'${NC}"
fi

echo
echo -e "${YELLOW}📋 Summary:${NC}"
echo "   • File created: $OUTPUT_FILE"
echo "   • Account ID: $ACCOUNT_ID"
echo "   • Tunnel ID: $TUNNEL_ID"
echo "   • Tunnel Name: $TUNNEL_NAME"
echo "   • Tunnel Secret: [hidden]"
echo
echo -e "${YELLOW}🚀 Next steps:${NC}"
echo "   1. Review: cat $OUTPUT_FILE"
echo "   2. Commit: git add $OUTPUT_FILE"
echo "   3. Push: git commit -m 'Add Cloudflared sealed secret' && git push"
echo "   4. Monitor: kubectl logs -n cloudflare-tunnel -l app=cloudflared"
echo
echo -e "${GREEN}✅ Done!${NC}"
