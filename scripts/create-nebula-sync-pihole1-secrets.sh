#!/bin/bash

# Script to create sealed secrets for nebula-sync-pihole1
# This syncs FROM a primary PiHole TO three replica PiHoles

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Nebula Sync PiHole1 Sealed Secrets Generator ===${NC}"
echo ""

# Check prerequisites
if ! command -v kubectl &>/dev/null; then
  echo -e "${RED}Error: kubectl is not installed${NC}"
  exit 1
fi

if ! command -v kubeseal &>/dev/null; then
  echo -e "${RED}Error: kubeseal is not installed${NC}"
  exit 1
fi

# Check if sealed-secrets controller is running
if ! kubectl get deployment sealed-secrets -n kube-system &>/dev/null; then
  echo -e "${RED}Error: Sealed Secrets controller is not running in kube-system namespace${NC}"
  exit 1
fi

echo -e "${YELLOW}This will create sealed secrets for nebula-sync-pihole1${NC}"
echo -e "${YELLOW}You need passwords for:${NC}"
echo -e "${YELLOW}  1. Primary PiHole (source)${NC}"
echo -e "${YELLOW}  2. Replica PiHole 1 (destination)${NC}"
echo -e "${YELLOW}  3. Replica PiHole 2 (destination)${NC}"
echo -e "${YELLOW}  4. Replica PiHole 3 (destination)${NC}"
echo ""

# Collect secrets
read -sp "Enter Primary PiHole password: " PRIMARY_PASSWORD
echo ""

read -sp "Enter Replica 1 PiHole password: " REPLICA1_PASSWORD
echo ""

read -sp "Enter Replica 2 PiHole password: " REPLICA2_PASSWORD
echo ""

read -sp "Enter Replica 3 PiHole password: " REPLICA3_PASSWORD
echo ""

# Validate inputs
if [ -z "$PRIMARY_PASSWORD" ]; then
  echo -e "${RED}Error: Primary password cannot be empty${NC}"
  exit 1
fi

if [ -z "$REPLICA1_PASSWORD" ]; then
  echo -e "${RED}Error: Replica 1 password cannot be empty${NC}"
  exit 1
fi

if [ -z "$REPLICA2_PASSWORD" ]; then
  echo -e "${RED}Error: Replica 2 password cannot be empty${NC}"
  exit 1
fi

if [ -z "$REPLICA3_PASSWORD" ]; then
  echo -e "${RED}Error: Replica 3 password cannot be empty${NC}"
  exit 1
fi

# Create temporary secret
TEMP_SECRET=$(mktemp)

cat >"$TEMP_SECRET" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: nebula-sync-pihole1-secrets
  namespace: pihole
type: Opaque
stringData:
  primary-password: "$PRIMARY_PASSWORD"
  replica-password-1: "$REPLICA1_PASSWORD"
  replica-password-2: "$REPLICA2_PASSWORD"
  replica-password-3: "$REPLICA3_PASSWORD"
EOF

# Define output path
OUTPUT_FILE="apps/nebula-sync-pihole1/overlay/korriban/sealed-secrets.yaml"

# Create sealed secret
echo -e "${GREEN}Creating sealed secret...${NC}"
kubeseal --format=yaml --cert=pub-sealed-secrets.pem <"$TEMP_SECRET" >"$OUTPUT_FILE"

# Clean up
rm "$TEMP_SECRET"

echo -e "${GREEN}✓ Sealed secret created at: ${OUTPUT_FILE}${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Review the generated file: ${OUTPUT_FILE}"
echo -e "  2. Commit and push to git repository"
echo -e "  3. FluxCD will reconcile and deploy the secret"
echo ""
echo -e "${GREEN}Done!${NC}"
