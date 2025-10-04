#!/bin/bash
# Script to create sealed secrets for Nebula Sync PiHole3
# Run from the repository root: ./scripts/create-nebula-sync-pihole3-secrets.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="pihole"
SECRET_NAME="nebula-sync-pihole3-secrets"
OUTPUT_FILE="apps/nebula-sync-pihole3/overlay/korriban/sealed-secrets.yaml"
SEALED_SECRETS_CONTROLLER_NAMESPACE="kube-system"
SEALED_SECRETS_CONTROLLER_NAME="sealed-secrets"
TEMP_SECRET_FILE="/tmp/nebula-sync-pihole3-secret.yaml"

echo -e "${BLUE}=== Nebula Sync PiHole3 Sealed Secrets Creator ===${NC}"
echo -e "${YELLOW}This script will create sealed secrets for nebula-sync-pihole3${NC}"
echo ""

# Check prerequisites
echo -e "${BLUE}Checking prerequisites...${NC}"

# Check if we're in the right directory
if [ ! -d "apps/nebula-sync-pihole3" ]; then
  echo -e "${RED}Error: Please run this script from the repository root${NC}"
  echo -e "${RED}Expected to find: apps/nebula-sync-pihole3/${NC}"
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
if ! kubectl get deployment ${SEALED_SECRETS_CONTROLLER_NAME} -n ${SEALED_SECRETS_CONTROLLER_NAMESPACE} &>/dev/null; then
  echo -e "${RED}Error: Sealed Secrets controller is not running in ${SEALED_SECRETS_CONTROLLER_NAMESPACE} namespace${NC}"
  echo -e "${YELLOW}Install with: kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.18.0/controller.yaml${NC}"
  exit 1
fi

echo -e "${GREEN}✓ All prerequisites met${NC}"
echo ""

# Prompt for passwords
echo -e "${BLUE}Enter PiHole passwords:${NC}"
echo -e "${YELLOW}Note: Passwords will be hidden as you type${NC}"
echo ""

# Primary password (pihole3)
read -s -p "Primary password (pihole3.home.cwbtech.net): " PRIMARY_PASSWORD
echo ""

# Replica password (pihole4)
read -s -p "Replica password (pihole4.home.cwbtech.net): " REPLICA1_PASSWORD
echo ""

# Validate passwords
if [ -z "$PRIMARY_PASSWORD" ] || [ -z "$REPLICA1_PASSWORD" ]; then
  echo -e "${RED}Error: All passwords are required${NC}"
  exit 1
fi

echo ""
echo -e "${BLUE}Creating temporary secret...${NC}"

# Create temporary secret file
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

echo -e "${BLUE}Sealing secret...${NC}"

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Seal the secret
kubeseal \
  --controller-name=${SEALED_SECRETS_CONTROLLER_NAME} \
  --controller-namespace=${SEALED_SECRETS_CONTROLLER_NAMESPACE} \
  --format=yaml \
  <${TEMP_SECRET_FILE} \
  >${OUTPUT_FILE}

# Clean up temporary file
rm ${TEMP_SECRET_FILE}

echo ""
echo -e "${GREEN}✓ Sealed secret created successfully!${NC}"
echo -e "${GREEN}  Output: ${OUTPUT_FILE}${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "  1. Review the generated file: ${OUTPUT_FILE}"
echo -e "  2. Commit to git:"
echo -e "     ${YELLOW}git add ${OUTPUT_FILE}${NC}"
echo -e "     ${YELLOW}git commit -m 'Add nebula-sync-pihole3 sealed secrets'${NC}"
echo -e "     ${YELLOW}git push${NC}"
echo -e "  3. FluxCD will automatically deploy the secrets"
echo ""
echo -e "${BLUE}Configuration summary:${NC}"
echo -e "  Primary: pihole3.home.cwbtech.net"
echo -e "  Replica: pihole4.home.cwbtech.net"
echo -e "  Sync Schedule: Every 10 minutes"
echo -e "  DHCP Sync: Disabled"
echo ""
