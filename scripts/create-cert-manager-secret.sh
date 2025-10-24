#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Cert-Manager Cloudflare Sealed Secret Creator ===${NC}"
echo ""

# Prompt for Cloudflare API token
read -sp "Enter Cloudflare API Token: " API_TOKEN
echo ""
echo ""

# Validate input
if [ -z "$API_TOKEN" ]; then
  echo -e "${RED}❌ API token cannot be empty${NC}"
  exit 1
fi

echo -e "${BLUE}Creating sealed secret...${NC}"

# Create and seal the secret using the repo cert
kubectl create secret generic cloudflare-api-token \
  --from-literal=api-token="$API_TOKEN" \
  --namespace=cert-manager \
  --dry-run=client -o yaml |
  kubeseal --format yaml --cert public-cert.pem \
    >clusters/korriban/infrastructure/cert-manager/cloudflare-secret.yaml

echo -e "${GREEN}✅ Sealed secret created${NC}"
echo ""
echo -e "${GREEN}=== Success! ===${NC}"
echo -e "${YELLOW}File updated:${NC}"
echo "  ✓ clusters/korriban/infrastructure/cert-manager/cloudflare-secret.yaml"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Commit and push the changes"
echo "  2. FluxCD will apply the sealed secret"
echo "  3. Cert-manager will be able to issue certificates"
