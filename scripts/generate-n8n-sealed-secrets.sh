#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== N8N Sealed Secrets Generator ===${NC}"
echo ""

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

if [ -z "$POSTGRES_PASSWORD" ] || [ -z "$REDIS_PASSWORD" ]; then
  echo -e "${RED}Error: Passwords cannot be empty${NC}"
  exit 1
fi

echo ""
echo -e "${GREEN}Generating sealed secrets...${NC}"

# Create temporary secret
kubectl create secret generic n8n-secrets \
  --from-literal=postgres-user=n8n \
  --from-literal=postgres-password="$POSTGRES_PASSWORD" \
  --from-literal=redis-password="$REDIS_PASSWORD" \
  --namespace=n8n \
  --dry-run=client -o yaml |
  kubeseal --controller-namespace=kube-system \
    --controller-name=sealed-secrets \
    --format=yaml >sealed-secrets.yaml

echo -e "${GREEN}✓ Sealed secrets generated successfully!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Review the generated sealed-secrets.yaml file"
echo "2. Commit and push to trigger FluxCD"
echo ""
echo -e "${GREEN}Done!${NC}"
