#!/bin/bash
# Cloudflared Sealed Secret Creator
# Creates sealed secrets for Cloudflare Tunnel deployment

set -e

# Configuration
NAMESPACE="cloudflare-tunnel"
SECRET_NAME="cloudflare-tunnel-cloudflared"
OUTPUT_FILE="apps/cloudflared/overlay/korriban/sealed-secrets.yaml"

echo "=== Cloudflared Sealed Secret Creator ==="
echo

# Check if we're in the right directory
if [ ! -d "apps/cloudflared" ]; then
  echo "❌ Error: Please run this script from the repository root"
  echo "❌ Expected to find: apps/cloudflared/"
  exit 1
fi

# Check if kubectl is available
if ! command -v kubectl &>/dev/null; then
  echo "❌ Error: kubectl is not installed or not in PATH"
  exit 1
fi

# Check if kubeseal is available
if ! command -v kubeseal &>/dev/null; then
  echo "❌ Error: kubeseal is not installed or not in PATH"
  echo "Install with: brew install kubeseal (macOS)"
  exit 1
fi

# Check if we can connect to the cluster
if ! kubectl cluster-info &>/dev/null; then
  echo "❌ Error: Cannot connect to Kubernetes cluster"
  echo "Make sure your kubeconfig is set up correctly"
  exit 1
fi

# Get credentials
echo "Enter Cloudflare tunnel credentials:"
read -p "Account ID: " ACCOUNT_ID
read -p "Tunnel ID: " TUNNEL_ID
read -p "Tunnel Name: " TUNNEL_NAME
read -s -p "Tunnel Secret: " TUNNEL_SECRET
echo
echo

# Validate inputs
if [[ -z "$ACCOUNT_ID" || -z "$TUNNEL_ID" || -z "$TUNNEL_NAME" || -z "$TUNNEL_SECRET" ]]; then
  echo "❌ Error: All fields are required"
  exit 1
fi

# Create temp files
TEMP_DIR=$(mktemp -d)
CREDENTIALS_FILE="$TEMP_DIR/credentials.json"
SECRET_FILE="$TEMP_DIR/secret.yaml"
SEALED_FILE="$TEMP_DIR/sealed.yaml"

# Clean up on exit
trap "rm -rf $TEMP_DIR" EXIT

echo "✅ Creating credentials file..."

# Create the JSON credentials file (properly formatted)
cat >"$CREDENTIALS_FILE" <<EOF
{"AccountTag":"$ACCOUNT_ID","TunnelID":"$TUNNEL_ID","TunnelName":"$TUNNEL_NAME","TunnelSecret":"$TUNNEL_SECRET"}
EOF

echo "✅ Creating Kubernetes secret from credentials file..."

# Create the secret from the credentials file
kubectl create secret generic "$SECRET_NAME" \
  --namespace="$NAMESPACE" \
  --from-file=credentials.json="$CREDENTIALS_FILE" \
  --dry-run=client -o yaml >"$SECRET_FILE"

# Add labels to the secret
cat >>"$SECRET_FILE" <<EOF
  labels:
    app.kubernetes.io/name: cloudflared
    app.kubernetes.io/part-of: cloudflare-tunnel
EOF

echo "✅ Sealing secret..."

# Seal the secret
kubeseal -f "$SECRET_FILE" -w "$SEALED_FILE" \
  --controller-name=sealed-secrets \
  --controller-namespace=kube-system \
  --format yaml

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Copy to final location
cp "$SEALED_FILE" "$OUTPUT_FILE"

echo "✅ SUCCESS!"
echo
echo "Sealed secret created: $OUTPUT_FILE"
echo

echo "Next steps:"
echo "  1. Review the generated file"
echo "  2. Commit to git and push"
echo "  3. FluxCD will deploy automatically"
echo
