#!/bin/bash

# Script to create Renovate sealed secrets for GitHub PAT
# Run this from the root of your repository

set -e

# Configuration
NAMESPACE="renovate"
SECRET_NAME="renovate-token"
OUTPUT_FILE="apps/renovate/overlay/korriban/sealed-secrets.yaml"
TEMP_SECRET_FILE="temp-renovate-secret.yaml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔐 Creating Renovate Sealed Secret${NC}"
echo "=============================================================="

# Check if we're in the repo root
if [ ! -d "apps/renovate" ]; then
  echo -e "${RED}❌ Please run this script from the root of your repository${NC}"
  echo "   Expected directory: apps/renovate"
  exit 1
fi

# Create the output directory if it doesn't exist
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Check if kubeseal is installed
if ! command -v kubeseal &>/dev/null; then
  echo -e "${RED}❌ kubeseal CLI not found. Please install it first:${NC}"
  echo "   brew install kubeseal"
  echo "   # or download from: https://github.com/bitnami-labs/sealed-secrets/releases"
  exit 1
fi

# Check if sealed-secrets controller is running
if ! kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets | grep -q Running; then
  echo -e "${RED}❌ Sealed Secrets controller not found or not running${NC}"
  echo "   Please ensure sealed-secrets is deployed first"
  exit 1
fi

echo -e "${YELLOW}📝 GitHub Personal Access Token (PAT) Setup${NC}"
echo ""
echo "You need a GitHub PAT with the following permissions:"
echo "  - repo (Full control of private repositories)"
echo ""
echo "To create a PAT:"
echo "  1. Go to https://github.com/settings/tokens"
echo "  2. Click 'Generate new token (classic)'"
echo "  3. Select 'repo' scope"
echo "  4. Set expiration (90 days recommended)"
echo "  5. Generate and copy the token"
echo ""
echo -e "${YELLOW}📝 Enter your GitHub Personal Access Token:${NC}"
read -s GITHUB_TOKEN

if [ -z "$GITHUB_TOKEN" ]; then
  echo -e "${RED}❌ GitHub token cannot be empty${NC}"
  exit 1
fi

echo ""
echo -e "${GREEN}✅ Creating sealed secret...${NC}"

# Create the secret file
cat >"$TEMP_SECRET_FILE" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: $SECRET_NAME
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: renovate
    app.kubernetes.io/part-of: automation
type: Opaque
data:
  token: $(echo -n "$GITHUB_TOKEN" | base64 -w 0 2>/dev/null || echo -n "$GITHUB_TOKEN" | base64)
EOF

# Generate the sealed secret
kubeseal -f "$TEMP_SECRET_FILE" -o yaml \
  --controller-name sealed-secrets \
  --controller-namespace kube-system >"$OUTPUT_FILE"

if [ $? -ne 0 ]; then
  echo -e "${RED}❌ Failed to create sealed secret${NC}"
  rm -f "$TEMP_SECRET_FILE"
  exit 1
fi

if [ -f "$OUTPUT_FILE" ] && [ -s "$OUTPUT_FILE" ]; then
  echo -e "${GREEN}🎉 Success! Renovate sealed secret has been created!${NC}"
  echo ""
  echo -e "${YELLOW}📋 Summary:${NC}"
  echo "   • File created: $OUTPUT_FILE"
  echo "   • Secret name: $SECRET_NAME"
  echo "   • Namespace: $NAMESPACE"
  echo "   • GitHub token: [hidden]"
  echo ""
  echo -e "${YELLOW}🚀 Next steps:${NC}"
  echo "   1. Review the file: $OUTPUT_FILE"
  echo "   2. Commit your changes: git add $OUTPUT_FILE"
  echo "   3. Deploy: git commit -m 'Add Renovate sealed secrets' && git push"
  echo ""
  echo -e "${GREEN}💡 Renovate Configuration:${NC}"
  echo "   • Repository: cbown75/kubernetes"
  echo "   • Schedule: Daily at 1:00 AM Arizona time"
  echo "   • Managers: flux, kubernetes, helm-values"
  echo ""
  echo -e "${YELLOW}⚠️  Important:${NC}"
  echo "   • GitHub PATs expire - remember to rotate them periodically"
  echo "   • Recommended expiration: 90 days"
  echo "   • When rotating, re-run this script and commit the new sealed secret"
else
  echo -e "${RED}❌ Failed to create sealed secret file${NC}"
  echo "   Please check permissions and try again"
fi

# Clean up temporary files
echo -e "${YELLOW}🧹 Cleaning up temporary files...${NC}"
rm -f "$TEMP_SECRET_FILE"

echo -e "${GREEN}✅ Done!${NC}"
