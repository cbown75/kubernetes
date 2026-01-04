#!/bin/bash

# Script to create SearXNG sealed secrets (Redis password and SearXNG secret key)
# Run this from the root of your repository

set -e

# Configuration
NAMESPACE="searxng"
SECRET_NAME="searxng-secrets"
OUTPUT_FILE="apps/searxng/overlay/korriban/sealed-secrets.yaml"
TEMP_SECRET_FILE="temp-searxng-secret.yaml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Creating SearXNG Sealed Secrets${NC}"
echo "=============================================================="

# Check if we're in the repo root
if [ ! -d "apps/searxng" ]; then
  echo -e "${RED}Please run this script from the root of your repository${NC}"
  echo "   Expected directory: apps/searxng"
  exit 1
fi

# Create the output directory if it doesn't exist
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Check if kubeseal is installed
if ! command -v kubeseal &>/dev/null; then
  echo -e "${RED}kubeseal CLI not found. Please install it first:${NC}"
  echo "   brew install kubeseal"
  echo "   # or download from: https://github.com/bitnami-labs/sealed-secrets/releases"
  exit 1
fi

# Check if sealed-secrets controller is running
if ! kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets | grep -q Running; then
  echo -e "${RED}Sealed Secrets controller not found or not running${NC}"
  echo "   Please ensure sealed-secrets is deployed first"
  exit 1
fi

# Generate random passwords
echo -e "${YELLOW}Generating secure random secrets...${NC}"
REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)
SEARXNG_SECRET=$(openssl rand -hex 32)

echo -e "${GREEN}Creating secrets...${NC}"

# Create the secret file
cat >"$TEMP_SECRET_FILE" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: $SECRET_NAME
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: searxng
    app.kubernetes.io/part-of: search-stack
type: Opaque
data:
  redis-password: $(echo -n "$REDIS_PASSWORD" | base64 -w 0)
  searxng-secret: $(echo -n "$SEARXNG_SECRET" | base64 -w 0)
EOF

# Generate the sealed secret
kubeseal -f "$TEMP_SECRET_FILE" -o yaml \
  --controller-name sealed-secrets \
  --controller-namespace kube-system >"temp-searxng-sealed-secret.yaml"

if [ $? -ne 0 ]; then
  echo -e "${RED}Failed to create sealed secret${NC}"
  rm -f "$TEMP_SECRET_FILE"
  exit 1
fi

# Extract encrypted data
ENCRYPTED_REDIS_PASSWORD=$(grep "redis-password:" temp-searxng-sealed-secret.yaml | awk '{print $2}')
ENCRYPTED_SEARXNG_SECRET=$(grep "searxng-secret:" temp-searxng-sealed-secret.yaml | awk '{print $2}')

echo -e "${GREEN}Creating sealed-secrets.yaml file...${NC}"

# Create the final sealed secrets file
cat >"$OUTPUT_FILE" <<EOF
---
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: $SECRET_NAME
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: searxng
    app.kubernetes.io/part-of: search-stack
spec:
  encryptedData:
    redis-password: "$ENCRYPTED_REDIS_PASSWORD"
    searxng-secret: "$ENCRYPTED_SEARXNG_SECRET"
  template:
    metadata:
      name: $SECRET_NAME
      namespace: $NAMESPACE
      labels:
        app.kubernetes.io/name: searxng
        app.kubernetes.io/part-of: search-stack
    type: Opaque
EOF

if [ -f "$OUTPUT_FILE" ] && [ -s "$OUTPUT_FILE" ]; then
  echo -e "${GREEN}Success! Sealed secrets have been created!${NC}"
  echo ""
  echo -e "${YELLOW}Summary:${NC}"
  echo "   File created: $OUTPUT_FILE"
  echo "   Redis password: [auto-generated, 32 chars]"
  echo "   SearXNG secret: [auto-generated, 64 hex chars]"
  echo ""
  echo -e "${YELLOW}Next steps:${NC}"
  echo "   1. Review the file: $OUTPUT_FILE"
  echo "   2. Commit your changes: git add $OUTPUT_FILE"
  echo "   3. Deploy: git commit -m 'Add SearXNG sealed secrets' && git push"
else
  echo -e "${RED}Failed to create sealed secret file${NC}"
  echo "   Please check permissions and try again"
fi

# Clean up temporary files
echo -e "${YELLOW}Cleaning up temporary files...${NC}"
rm -f "$TEMP_SECRET_FILE" temp-searxng-sealed-secret.yaml

echo -e "${GREEN}Done!${NC}"
