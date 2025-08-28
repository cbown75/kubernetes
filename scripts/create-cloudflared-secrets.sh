#!/usr/bin/env zsh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="cloudflare-tunnel"
SECRET_NAME="cloudflare-tunnel-cloudflared"
OUTPUT_FILE="clusters/korriban/apps/cloudflared/sealed-secret.yaml"
SEALED_SECRETS_CONTROLLER_NAMESPACE="kube-system"
SEALED_SECRETS_CONTROLLER_NAME="sealed-secrets"

echo -e "${BLUE}=== Cloudflared Tunnel Sealed Secrets Creator ===${NC}"
echo -e "${YELLOW}This script will create sealed secrets for Cloudflared tunnel${NC}"
echo ""

echo -e "${BLUE}Checking prerequisites...${NC}"

if [ ! -f "clusters/korriban/apps/cloudflared/release.yaml" ]; then
  echo -e "${RED}Error: Please run this script from the repository root${NC}"
  echo -e "${RED}Expected to find: clusters/korriban/apps/cloudflared/release.yaml${NC}"
  exit 1
fi

if ! command -v kubectl &>/dev/null; then
  echo -e "${RED}Error: kubectl is not installed or not in PATH${NC}"
  exit 1
fi

if ! command -v kubeseal &>/dev/null; then
  echo -e "${RED}Error: kubeseal is not installed or not in PATH${NC}"
  echo -e "${YELLOW}Install with: brew install kubeseal (macOS) or download from https://github.com/bitnami-labs/sealed-secrets/releases${NC}"
  exit 1
fi

if ! kubectl cluster-info &>/dev/null; then
  echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
  echo -e "${YELLOW}Make sure your kubeconfig is set up correctly${NC}"
  exit 1
fi

if ! kubectl get pods -n "$SEALED_SECRETS_CONTROLLER_NAMESPACE" -l "app.kubernetes.io/name=$SEALED_SECRETS_CONTROLLER_NAME" | grep -q Running; then
  echo -e "${RED}Error: Sealed Secrets controller is not running${NC}"
  echo -e "${YELLOW}Please ensure sealed-secrets is deployed first${NC}"
  exit 1
fi

echo -e "${GREEN}✅ All prerequisites met${NC}"
echo ""

echo -e "${YELLOW}📝 Enter your Cloudflare tunnel token:${NC}"
echo -e "${BLUE}(Get this from Cloudflare Zero Trust Dashboard → Networks → Tunnels)${NC}"
read -s TUNNEL_TOKEN

if [ -z "$TUNNEL_TOKEN" ]; then
  echo -e "${RED}❌ Tunnel token cannot be empty${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Creating sealed secret...${NC}"

kubectl create secret generic "$SECRET_NAME" \
  --from-literal=tunnelToken="$TUNNEL_TOKEN" \
  --namespace="$NAMESPACE" \
  --dry-run=client -o yaml |
  kubeseal -o yaml \
    --controller-name="$SEALED_SECRETS_CONTROLLER_NAME" \
    --controller-namespace="$SEALED_SECRETS_CONTROLLER_NAMESPACE" >"$OUTPUT_FILE"

if [ $? -eq 0 ]; then
  echo -e "${GREEN}🎉 Success! Sealed secret created at: ${OUTPUT_FILE}${NC}"
  echo ""
  echo -e "${YELLOW}📋 Next steps:${NC}"
  echo "   1. Review the file: $OUTPUT_FILE"
  echo "   2. Update tunnel ID in clusters/korriban/apps/cloudflared/release.yaml"
  echo "   3. Add 'cloudflared' to clusters/korriban/apps/kustomization.yaml"
  echo "   4. Commit and push:"
  echo "      git add clusters/korriban/apps/cloudflared/"
  echo "      git commit -m \"Add cloudflared tunnel deployment\""
  echo "      git push"
  echo ""
  echo -e "${BLUE}ℹ️  Remember to configure your tunnel routes in Cloudflare Dashboard${NC}"
else
  echo -e "${RED}❌ Failed to create sealed secret${NC}"
  exit 1
fi
