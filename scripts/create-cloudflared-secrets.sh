#!/usr/bin/env bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="cloudflare-tunnel"
SECRET_NAME="cloudflare-tunnel-cloudflared"
OUTPUT_FILE="clusters/korriban/apps/cloudflared/sealed-secret.yaml" # SAME FILE

echo -e "${BLUE}=== Update Existing Sealed Secret for GitOps ===${NC}"
echo -e "${YELLOW}This will REPLACE your existing sealed-secret.yaml with credentials.json format${NC}"
echo ""

echo -e "${BLUE}You'll need to provide your tunnel credentials manually.${NC}"

echo -e "${BLUE}Now we need the tunnel credentials. Run these commands:${NC}"
echo -e "${YELLOW}1. cloudflared tunnel list${NC}"
echo -e "${YELLOW}2. cat ~/.cloudflared/<tunnel-id>.json${NC}"
echo ""
echo -e "${BLUE}Or check your Cloudflare dashboard for tunnel details.${NC}"
echo ""

echo -e "${YELLOW}Enter your Cloudflare Account ID:${NC}"
read -r ACCOUNT_ID

echo -e "${YELLOW}Enter your Tunnel ID (UUID format):${NC}"
read -r TUNNEL_ID

echo -e "${YELLOW}Enter your Tunnel Name:${NC}"
read -r TUNNEL_NAME

echo -e "${YELLOW}Enter your Tunnel Secret (from credentials file or dashboard):${NC}"
read -s TUNNEL_SECRET
echo ""

# Create credentials.json
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

echo -e "${GREEN}Updating existing sealed secret file...${NC}"

# REPLACE the existing sealed-secret.yaml file
kubectl create secret generic "$SECRET_NAME" \
  --from-literal=credentials.json="$CREDENTIALS_JSON" \
  --namespace="$NAMESPACE" \
  --dry-run=client -o yaml |
  kubeseal -o yaml \
    --controller-name="sealed-secrets" \
    --controller-namespace="kube-system" >"$OUTPUT_FILE"

if [ $? -eq 0 ]; then
  echo -e "${GREEN}🎉 Success! Updated ${OUTPUT_FILE}${NC}"
  echo ""
  echo -e "${YELLOW}📋 Tunnel Information for release.yaml:${NC}"
  echo "   Tunnel UUID: $TUNNEL_ID"
  echo ""
  echo -e "${YELLOW}📋 Next steps:${NC}"
  echo "   1. Update tunnel UUID in release.yaml: $TUNNEL_ID"
  echo "   2. Update release.yaml to use cloudflare-tunnel chart"
  echo "   3. Commit and push"
  echo ""
  echo -e "${BLUE}ℹ️  Your existing file has been replaced with GitOps format${NC}"
else
  echo -e "${RED}❌ Failed to update sealed secret${NC}"
  exit 1
fi
