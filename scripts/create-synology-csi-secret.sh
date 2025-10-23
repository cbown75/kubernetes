#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Synology CSI Sealed Secret Creator ===${NC}"
echo ""

# Check we're in repo root
if [ ! -f "clusters/korriban/infrastructure/storage/client-info.yaml" ]; then
  echo -e "${RED}❌ Cannot find clusters/korriban/infrastructure/storage/client-info.yaml${NC}"
  exit 1
fi

if [ ! -f "public-cert.pem" ]; then
  echo -e "${RED}❌ Cannot find public-cert.pem in repo root${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Found client-info.yaml${NC}"
echo -e "${GREEN}✅ Found public-cert.pem${NC}"

# The file is .yaml but needs to be .yml for the CSI driver
# Copy and rename it
cp clusters/korriban/infrastructure/storage/client-info.yaml /tmp/client-info.yml

echo -e "${BLUE}Creating sealed secret...${NC}"

# Create and seal the secret using the cert in the repo
kubectl create secret generic synology-csi-config \
  --from-file=client-info.yml=/tmp/client-info.yml \
  --namespace=kube-system \
  --dry-run=client -o yaml |
  kubeseal --format yaml --cert public-cert.pem \
    >/tmp/sealed.yaml

echo -e "${GREEN}✅ Sealed secret created${NC}"

# Update both locations
cp /tmp/sealed.yaml clusters/korriban/infrastructure/storage/sealed-secrets.yaml
cp /tmp/sealed.yaml infrastructure/storage/synology-csi-driver/templates/sealed-secret.yaml

# Cleanup
rm /tmp/client-info.yml /tmp/sealed.yaml

echo ""
echo -e "${GREEN}=== Success! ===${NC}"
echo -e "${YELLOW}Files updated:${NC}"
echo "  ✓ clusters/korriban/infrastructure/storage/sealed-secrets.yaml"
echo "  ✓ infrastructure/storage/synology-csi-driver/templates/sealed-secret.yaml"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Commit and push the changes"
echo "  2. FluxCD will apply the sealed secret"
echo "  3. CSI driver will start working"
