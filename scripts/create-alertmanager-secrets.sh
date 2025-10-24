#!/usr/bin/env zsh

# Script to create sealed secrets for AlertManager - zsh compatible
# Run from the repository root: ./scripts/create-alertmanager-secrets.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="monitoring"
SECRET_NAME="alertmanager-secrets"
OUTPUT_FILE="apps/alertmanager/overlay/korriban/sealed-secrets.yaml"
SEALED_SECRETS_CONTROLLER_NAMESPACE="kube-system"
SEALED_SECRETS_CONTROLLER_NAME="sealed-secrets"

echo -e "${BLUE}=== AlertManager Sealed Secrets Creator ===${NC}"
echo -e "${YELLOW}This script will create sealed secrets for AlertManager${NC}"
echo ""

# Check prerequisites
echo -e "${BLUE}Checking prerequisites...${NC}"

# Check if we're in the right directory
if [ ! -d "apps/alertmanager" ]; then
  echo -e "${RED}Error: Please run this script from the repository root${NC}"
  echo -e "${RED}Expected to find: apps/alertmanager/${NC}"
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
if ! kubectl get pods -n $SEALED_SECRETS_CONTROLLER_NAMESPACE -l app.kubernetes.io/name=sealed-secrets | grep -q Running; then
  echo -e "${RED}Error: Sealed Secrets controller is not running${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Prerequisites check passed${NC}"
echo ""

# Helper function to get user input
get_input() {
  local prompt=$1
  local default=$2
  local result

  echo -n "$prompt"
  read result
  echo ${result:-$default}
}

# Helper function to get secret input (hidden)
get_secret() {
  local prompt=$1
  local result

  echo -n "$prompt"
  read -s result
  echo "" # New line after hidden input
  echo $result
}

# Collect secrets
echo -e "${BLUE}=== Collecting Secrets ===${NC}"
echo "Note: Some secrets are optional. Press Enter to skip."
echo ""

# Required: Slack webhook URL
SLACK_WEBHOOK_URL=$(get_secret "Slack Webhook URL (required): ")
if [ -z "$SLACK_WEBHOOK_URL" ]; then
  echo -e "${RED}Error: Slack webhook URL is required${NC}"
  exit 1
fi

# Optional: SMTP password
SMTP_PASSWORD=$(get_secret "SMTP Password (optional, press Enter to skip): ")

# Optional: Webhook password (with auto-generation option)
echo -e "${YELLOW}Webhook Password (optional, press Enter to generate random):${NC}"
WEBHOOK_PASSWORD=$(get_secret "")
if [ -z "$WEBHOOK_PASSWORD" ]; then
  WEBHOOK_PASSWORD=$(openssl rand -base64 24)
  echo -e "${GREEN}Generated random webhook password: $WEBHOOK_PASSWORD${NC}"
  echo -e "${YELLOW}Please save this password - you'll need it to configure webhooks${NC}"
fi

# Optional: PagerDuty key
PAGERDUTY_KEY=$(get_secret "PagerDuty Integration Key (optional, press Enter to skip): ")

echo ""
echo -e "${GREEN}✓ Secrets collected${NC}"
echo ""

# Create the secret manifest
echo -e "${BLUE}Creating sealed secret...${NC}"

# Build the secret data
SECRET_DATA=""
if [ -n "$SLACK_WEBHOOK_URL" ]; then
  SECRET_DATA="$SECRET_DATA  --from-literal=slack-webhook-url=\"$SLACK_WEBHOOK_URL\""
fi
if [ -n "$SMTP_PASSWORD" ]; then
  SECRET_DATA="$SECRET_DATA  --from-literal=smtp-password=\"$SMTP_PASSWORD\""
fi
if [ -n "$WEBHOOK_PASSWORD" ]; then
  SECRET_DATA="$SECRET_DATA  --from-literal=webhook-password=\"$WEBHOOK_PASSWORD\""
fi
if [ -n "$PAGERDUTY_KEY" ]; then
  SECRET_DATA="$SECRET_DATA  --from-literal=pagerduty-key=\"$PAGERDUTY_KEY\""
fi

# Create the output directory if it doesn't exist
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Create sealed secret using kubectl + kubeseal
eval "kubectl create secret generic $SECRET_NAME \
    --namespace=$NAMESPACE \
    $SECRET_DATA \
    --dry-run=client -o yaml" |
  kubeseal \
    --controller-name=$SEALED_SECRETS_CONTROLLER_NAME \
    --controller-namespace=$SEALED_SECRETS_CONTROLLER_NAMESPACE \
    --format=yaml \
    >"$OUTPUT_FILE"

# Add proper labels to the SealedSecret (sed is more portable than yaml manipulation)
# Create a temp file with proper pattern
cat <<EOF >"${OUTPUT_FILE}.tmp"
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: $SECRET_NAME
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: alertmanager
    app.kubernetes.io/part-of: monitoring-stack
EOF

# Extract everything from spec: onwards from the generated file and append
sed -n '/^spec:/,$ p' "$OUTPUT_FILE" >>"${OUTPUT_FILE}.tmp"

# Replace the original file
mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"

echo -e "${GREEN}✓ Sealed secret created: $OUTPUT_FILE${NC}"
echo ""

# Show summary
echo -e "${BLUE}=== Summary ===${NC}"
echo -e "${GREEN}Created sealed secret with the following keys:${NC}"

if [ -n "$SLACK_WEBHOOK_URL" ]; then
  echo -e "${GREEN}  ✓ slack-webhook-url${NC}"
fi

if [ -n "$SMTP_PASSWORD" ]; then
  echo -e "${GREEN}  ✓ smtp-password${NC}"
fi

if [ -n "$WEBHOOK_PASSWORD" ]; then
  echo -e "${GREEN}  ✓ webhook-password${NC}"
fi

if [ -n "$PAGERDUTY_KEY" ]; then
  echo -e "${GREEN}  ✓ pagerduty-key${NC}"
fi

echo ""
echo -e "${BLUE}=== Next Steps ===${NC}"
echo -e "${YELLOW}1. Review the generated file: $OUTPUT_FILE${NC}"
echo -e "${YELLOW}2. Commit the file to git:${NC}"
echo -e "   ${BLUE}git add $OUTPUT_FILE${NC}"
echo -e "   ${BLUE}git commit -m \"Add AlertManager sealed secrets\"${NC}"
echo -e "   ${BLUE}git push${NC}"
echo -e "${YELLOW}3. FluxCD will automatically deploy the secrets${NC}"
echo -e "${YELLOW}4. Deploy AlertManager with the updated kustomization${NC}"
echo ""
echo -e "${GREEN}✓ Sealed secret creation complete!${NC}"
