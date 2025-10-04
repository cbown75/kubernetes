#!/bin/bash
# Script to create sealed secrets for Nebula Sync PiHole5
# Run from the repository root: ./scripts/create-nebula-sync-pihole5-secrets.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="pihole"
SECRET_NAME="nebula-sync-pihole5-secrets"
OUTPUT_FILE="apps/nebula-sync-pihole5/overlay/korriban/sealed-secrets.yaml"
SEALED_SECRETS_CONTROLLER_NAMESPACE="kube-system"
SEALED_SECRETS_CONTROLLER_NAME="sealed-secrets"
TEMP_SECRET_FILE="/tmp/nebula-sync-pihole5-secret.yaml"

echo -e "${BLUE}=== Nebula Sync PiHole5 Sealed Secrets Creator ===${NC}"
echo -e "${YELLOW}This script will create sealed secrets for nebula-sync-pihole5${NC}"
echo ""

# Check prerequisites
echo -e "${BLUE}Checking prerequisites...${NC}"

# Check if we're in the right directory
if [ ! -d "apps/nebula-sync-pihole5" ]; then
  echo -e "${RED}Error: Please run this script from the repository root${NC}"
  echo -e "${RED}Expected to find: apps/nebula-sync-pihole5/${NC}"
  exit 1
fi

# Check if kubectl is available
if ! command -v kubectl &>/dev/null; then
  echo -e "${RED}Error: kubectl is not installed or not in PATH${NC}"
  exit 1
fi

# Check if kubeseal is available
if ! command -v kubeseal &>/dev/null; then
  echo -e "${RED}Error: kubeseal is not installed or not in PATH${NC}"
  echo -e "${YELLOW}Install with: brew install kubeseal (macOS) or download from https://github.com/bitnami-labs/sealed-secrets/releases${NC}"
  exit 1
fi

# Check if we can connect to the cluster
if ! kubectl cluster-info &>/dev/null; then
  echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
  echo -e "${YELLOW}Make sure your kubeconfig is set up correctly${NC}"
  exit 1
fi

# Check if sealed-secrets controller is running
if ! kubectl get deployment -n ${SEALED_SECRETS_CONTROLLER_NAMESPACE} ${SEALED_SECRETS_CONTROLLER_NAME} &>/dev/null; then
  echo -e "${RED}Error: Sealed Secrets controller not found in ${SEALED_SECRETS_CONTROLLER_NAMESPACE} namespace${NC}"
  echo -e "${YELLOW}Make sure sealed-secrets is installed in your cluster${NC}"
  exit 1
fi

echo -e "${GREEN}✓ All prerequisites met${NC}"
echo ""

# Prompt for passwords
echo -e "${BLUE}Enter passwords for PiHole instances:${NC}"
echo -e "${YELLOW}Note: Passwords will not be displayed${NC}"
echo ""

read -sp "Primary password (pihole5.home.cwbtech.net): " PRIMARY_PASSWORD
echo ""

read -sp "Replica password (pihole6.home.cwbtech.net): " REPLICA1_PASSWORD
echo ""
echo ""

# Validate passwords are not empty
if [ -z "$PRIMARY_PASSWORD" ]; then
  echo -e "${RED}Error: Primary password cannot be empty${NC}"
  exit 1
fi

if [ -z "$REPLICA1_PASSWORD" ]; then
  echo -e "${RED}Error: Replica password cannot be empty${NC}"
  exit 1
fi

# Create temporary secret
echo -e "${BLUE}Creating temporary secret...${NC}"
cat <<EOF >${TEMP_SECRET_FILE}
apiVersion: v1
kind: Secret
metadata:
  name: ${SECRET_NAME}
  namespace: ${NAMESPACE}
type: Opaque
stringData:
  primary-password: "${PRIMARY_PASSWORD}"
  replica-password-1: "${REPLICA1_PASSWORD}"
EOF

echo -e "${GREEN}✓ Temporary secret created${NC}"
echo ""

# Seal the secret
echo -e "${BLUE}Sealing secret with kubeseal...${NC}"
if ! kubeseal \
  --controller-name=${SEALED_SECRETS_CONTROLLER_NAME} \
  --controller-namespace=${SEALED_SECRETS_CONTROLLER_NAMESPACE} \
  --format=yaml \
  <${TEMP_SECRET_FILE} \
  >${OUTPUT_FILE}; then
  echo -e "${RED}Error: Failed to seal secret${NC}"
  rm -f ${TEMP_SECRET_FILE}
  exit 1
fi

echo -e "${GREEN}✓ Secret sealed successfully${NC}"
echo ""

# Clean up temporary file
echo -e "${BLUE}Cleaning up temporary files...${NC}"
rm -f ${TEMP_SECRET_FILE}
echo -e "${GREEN}✓ Cleanup complete${NC}"
echo ""

# Display summary
echo -e "${GREEN}=== Success ===${NC}"
echo -e "${GREEN}Sealed secret created at: ${OUTPUT_FILE}${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Review the sealed secret file"
echo -e "2. Commit and push the changes:"
echo -e "   ${BLUE}git add ${OUTPUT_FILE}${NC}"
echo -e "   ${BLUE}git commit -m 'Add sealed secrets for nebula-sync-pihole5'${NC}"
echo -e "   ${BLUE}git push${NC}"
echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo -e "Primary: pihole5.home.cwbtech.net"
echo -e "Replica: pihole6.home.cwbtech.net"
echo -e "Sync Schedule: Every 10 minutes"
echo ""
