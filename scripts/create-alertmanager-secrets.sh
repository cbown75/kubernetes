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
  echo -e "${RED}Expected to find: apps/alertmanager/ directory${NC}"
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
if ! kubectl get deployment "$SEALED_SECRETS_CONTROLLER_NAME" -n "$SEALED_SECRETS_CONTROLLER_NAMESPACE" &>/dev/null; then
  echo -e "${RED}Error: Sealed Secrets controller not found${NC}"
  echo -e "${YELLOW}Expected: deployment/$SEALED_SECRETS_CONTROLLER_NAME in namespace $SEALED_SECRETS_CONTROLLER_NAMESPACE${NC}"
  exit 1
fi

echo -e "${GREEN}✓ All prerequisites met${NC}"
echo ""

# Initialize variables
SLACK_WEBHOOK_URL=""
SMTP_PASSWORD=""
WEBHOOK_PASSWORD=""
PAGERDUTY_KEY=""

echo -e "${BLUE}=== Collecting Secrets ===${NC}"
echo ""

# Slack Webhook URL (required)
echo -e "${BLUE}Enter slack-webhook-url:${NC}"
echo -e "${YELLOW}Slack webhook URL (from your Slack app: https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK)${NC}"
while true; do
  echo -n "Value: "
  read -r SLACK_WEBHOOK_URL

  if [ -z "$SLACK_WEBHOOK_URL" ]; then
    echo -e "${RED}Error: This secret is required${NC}"
    echo -e "${RED}Please try again${NC}"
    continue
  fi

  # Show confirmation
  first_chars="${SLACK_WEBHOOK_URL:0:30}"
  echo -e "${YELLOW}Entered URL starts with: $first_chars...${NC}"
  echo -n "Confirm this is correct (y/N): "
  read -r confirm

  if [[ $confirm =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}✓ Slack webhook URL stored${NC}"
    echo ""
    break
  else
    echo -e "${RED}Please try again${NC}"
  fi
done

# SMTP Password (optional)
echo -e "${BLUE}Enter smtp-password:${NC}"
echo -e "${YELLOW}SMTP password for sending email notifications (e.g., app password from Gmail, Outlook, etc.)${NC}"
echo -e "${YELLOW}(Optional - press Enter to skip)${NC}"
echo -n "Value: "
read -rs SMTP_PASSWORD
echo ""
if [ -n "$SMTP_PASSWORD" ]; then
  echo -e "${GREEN}✓ SMTP password stored${NC}"
else
  echo -e "${YELLOW}Skipped${NC}"
fi
echo ""

# Webhook Password (optional)
echo -e "${BLUE}For webhook authentication, you can generate a random password or provide your own:${NC}"
random_webhook_pass=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
echo -e "${YELLOW}Generated random password: ${random_webhook_pass:0:8}...${NC}"
echo -n "Use generated password for webhook auth? (Y/n): "
read -r use_generated

if [[ $use_generated =~ ^[Nn]$ ]]; then
  echo -e "${BLUE}Enter webhook-password:${NC}"
  echo -e "${YELLOW}Password for webhook authentication (used to secure webhook endpoints)${NC}"
  echo -e "${YELLOW}(Optional - press Enter to skip)${NC}"
  echo -n "Value: "
  read -rs WEBHOOK_PASSWORD
  echo ""
  if [ -n "$WEBHOOK_PASSWORD" ]; then
    echo -e "${GREEN}✓ Custom webhook password stored${NC}"
  else
    echo -e "${YELLOW}Skipped${NC}"
  fi
else
  WEBHOOK_PASSWORD="$random_webhook_pass"
  echo -e "${GREEN}✓ Using generated webhook password${NC}"
fi
echo ""

# PagerDuty Key (optional)
echo -e "${BLUE}Enter pagerduty-key:${NC}"
echo -e "${YELLOW}PagerDuty integration key (from your PagerDuty service integration)${NC}"
echo -e "${YELLOW}(Optional - press Enter to skip)${NC}"
echo -n "Value: "
read -rs PAGERDUTY_KEY
echo ""
if [ -n "$PAGERDUTY_KEY" ]; then
  echo -e "${GREEN}✓ PagerDuty key stored${NC}"
else
  echo -e "${YELLOW}Skipped${NC}"
fi
echo ""

echo -e "${BLUE}=== Creating Sealed Secret ===${NC}"

# Create temporary file for the secret
temp_secret_file=$(mktemp)
trap "rm -f $temp_secret_file" EXIT

# Create the secret YAML
echo -e "${YELLOW}Creating secret manifest...${NC}"

# Build the kubectl command properly
kubectl_cmd="kubectl create secret generic $SECRET_NAME --namespace=$NAMESPACE --dry-run=client -o yaml"
kubectl_cmd="$kubectl_cmd --from-literal=slack-webhook-url=$SLACK_WEBHOOK_URL"

# Add optional secrets if provided
if [ -n "$SMTP_PASSWORD" ]; then
  kubectl_cmd="$kubectl_cmd --from-literal=smtp-password=$SMTP_PASSWORD"
fi

if [ -n "$WEBHOOK_PASSWORD" ]; then
  kubectl_cmd="$kubectl_cmd --from-literal=webhook-password=$WEBHOOK_PASSWORD"
fi

if [ -n "$PAGERDUTY_KEY" ]; then
  kubectl_cmd="$kubectl_cmd --from-literal=pagerduty-key=$PAGERDUTY_KEY"
fi

# Execute the command
eval "$kubectl_cmd" >"$temp_secret_file"

# Create sealed secret
echo -e "${YELLOW}Sealing secret with controller in $SEALED_SECRETS_CONTROLLER_NAMESPACE...${NC}"
kubeseal --controller-namespace="$SEALED_SECRETS_CONTROLLER_NAMESPACE" --controller-name="$SEALED_SECRETS_CONTROLLER_NAME" --format=yaml <"$temp_secret_file" >"$OUTPUT_FILE"

# Add metadata and labels to match your pattern
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
echo -e "   ${BLUE}git commit -m \"Update AlertManager sealed secrets\"${NC}"
echo -e "   ${BLUE}git push${NC}"
echo -e "${YELLOW}3. FluxCD will automatically deploy the secrets${NC}"
echo -e "${YELLOW}4. Deploy AlertManager with the updated kustomization${NC}"
echo ""
echo -e "${GREEN}✓ Sealed secret creation complete!${NC}"

# Optional: Show the file content (without the secret values)
echo -n "Show generated sealed secret file? (y/N): "
read -r show_file
if [[ $show_file =~ ^[Yy]$ ]]; then
  echo ""
  echo -e "${BLUE}=== Generated File Content ===${NC}"
  cat "$OUTPUT_FILE"
fi
