#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_DIR="${REPO_ROOT}/apps/proxmox-exporter/overlay/korriban"
OUTPUT_FILE="${OUTPUT_DIR}/sealed-secrets.yaml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Proxmox Exporter Sealed Secrets Generator ===${NC}"
echo ""
echo "This script will create sealed secrets for the Proxmox exporter."
echo "You'll need API credentials from your Proxmox server."
echo ""
echo "To create an API token in Proxmox:"
echo "  1. Go to Datacenter -> Permissions -> API Tokens"
echo "  2. Add a new token for your user (e.g., prometheus@pve!monitoring)"
echo "  3. Grant it PVE.Auditor privileges"
echo ""

# Prompt for Proxmox credentials
read -p "Proxmox host (e.g., korriban.home.cwbtech.net): " PVE_HOST
read -p "Proxmox API user (e.g., prometheus@pve): " PVE_USER
read -sp "Proxmox API token (or password): " PVE_PASSWORD
echo ""

# Create temporary secret YAML
TMP_SECRET=$(mktemp)
cat > "${TMP_SECRET}" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: proxmox-exporter-credentials
  namespace: monitoring
  labels:
    app.kubernetes.io/name: proxmox-exporter
    app.kubernetes.io/part-of: monitoring-stack
type: Opaque
stringData:
  PVE_USER: "${PVE_USER}"
  PVE_PASSWORD: "${PVE_PASSWORD}"
  PVE_HOST: "${PVE_HOST}"
EOF

# Check if kubeseal is available
if ! command -v kubeseal &> /dev/null; then
    echo -e "${RED}Error: kubeseal is not installed${NC}"
    echo "Install it with: brew install kubeseal"
    rm -f "${TMP_SECRET}"
    exit 1
fi

# Create sealed secret
echo -e "${YELLOW}Creating sealed secret...${NC}"
kubeseal --format=yaml --cert="${HOME}/.sealed-secrets/pub-sealed-secrets.pem" \
    < "${TMP_SECRET}" > "${OUTPUT_FILE}"

# Clean up
rm -f "${TMP_SECRET}"

echo -e "${GREEN}✓ Sealed secret created at: ${OUTPUT_FILE}${NC}"
echo ""
echo "You can now commit this file to Git:"
echo "  git add ${OUTPUT_FILE}"
echo "  git commit -m 'Add Proxmox exporter sealed secrets'"
echo "  git push"
