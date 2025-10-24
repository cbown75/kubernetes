#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== N8N Sealed Secrets Generator ===${NC}"
echo ""

# Check if we're in the right directory
if [ ! -d "apps/n8n" ]; then
  echo -e "${RED}Error: Please run this script from the repository root${NC}"
  echo -e "${RED}Expected to find: apps/n8n/${NC}"
  exit 1
fi

# Check if kubeseal is installed
if ! command -v kubeseal &>/dev/null; then
  echo -e "${RED}Error: kubeseal is not installed${NC}"
  echo "Install it with: brew install kubeseal"
  exit 1
fi

# Check if kubectl is configured
if ! kubectl cluster-info &>/dev/null; then
  echo -e "${RED}Error: kubectl is not configured or cluster is not accessible${NC}"
  exit 1
fi

echo -e "${YELLOW}Enter PostgreSQL password:${NC}"
read -s POSTGRES_PASSWORD
echo ""

echo -e "${YELLOW}Enter Redis password:${NC}"
read -s REDIS_PASSWORD
echo ""

echo -e "${YELLOW}Enter N8N encryption key (or press enter to generate):${NC}"
read -s ENCRYPTION_KEY
echo ""

# Generate encryption key if not provided
if [ -z "$ENCRYPTION_KEY" ]; then
  echo -e "${YELLOW}Generating random encryption key...${NC}"
  ENCRYPTION_KEY=$(openssl rand -base64 24)
  echo -e "${GREEN}Generated encryption key: ${ENCRYPTION_KEY}${NC}"
fi

if [ -z "$POSTGRES_PASSWORD" ] || [ -z "$REDIS_PASSWORD" ]; then
  echo -e "${RED}Error: PostgreSQL and Redis passwords cannot be empty${NC}"
  exit 1
fi

echo ""
echo -e "${GREEN}Generating sealed secrets...${NC}"

# Create the output directory if it doesn't exist
mkdir -p apps/n8n/overlay/korriban

# Create temporary secret
kubectl create secret generic n8n-secrets \
  --from-literal=postgres-user=n8n \
  --from-literal=postgres-password="$POSTGRES_PASSWORD" \
  --from-literal=redis-password="$REDIS_PASSWORD" \
  --from-literal=encryption-key="$ENCRYPTION_KEY" \
  --namespace=n8n \
  --dry-run=client -o yaml |
  kubeseal --controller-namespace=kube-system \
    --controller-name=sealed-secrets \
    --format=yaml >apps/n8n/overlay/korriban/sealed-secrets.yaml

echo -e "${GREEN}✓ Sealed secrets generated successfully!${NC}"
echo ""
echo -e "${YELLOW}IMPORTANT: Save this encryption key securely:${NC}"
echo -e "${GREEN}${ENCRYPTION_KEY}${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Review the generated sealed-secrets.yaml file"
echo "2. Save the encryption key in a secure location (password manager)"
echo "3. Commit and push sealed-secrets.yaml to trigger FluxCD"
echo ""
echo -e "${GREEN}Done!${NC}"
