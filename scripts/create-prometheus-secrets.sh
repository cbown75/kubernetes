#!/usr/bin/env zsh

# Script to create sealed secrets for Prometheus - zsh compatible
# Run from the repository root: ./scripts/create-prometheus-secrets.sh
# Currently creates a placeholder secret for future use

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="monitoring"
SECRET_NAME="prometheus-secrets"
OUTPUT_FILE="apps/prometheus/overlay/korriban/sealed-secrets.yaml"
SEALED_SECRETS_CONTROLLER_NAMESPACE="kube-system"
SEALED_SECRETS_CONTROLLER_NAME="sealed-secrets"

echo -e "${BLUE}=== Prometheus Sealed Secrets Creator ===${NC}"
echo -e "${YELLOW}This script creates a placeholder sealed secret for Prometheus${NC}"
echo -e "${YELLOW}Note: Prometheus is currently accessible without authentication${NC}"
echo ""

# Check prerequisites
echo -e "${BLUE}Checking prerequisites...${NC}"

# Check if we're in the right directory
if [ ! -d "apps/prometheus" ]; then
  echo -e "${RED}Error: Please run this script from the repository root${NC}"
  echo -e "${RED}Expected to find: apps/prometheus/${NC}"
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

# Create placeholder secret
echo -e "${BLUE}Creating placeholder sealed secret...${NC}"
echo -e "${YELLOW}Note: This is a placeholder. Update with actual secrets when needed.${NC}"
echo ""

# Create the output directory if it doesn't exist
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Create sealed secret with placeholder data
kubectl create secret generic $SECRET_NAME \
  --namespace=$NAMESPACE \
  --from-literal=placeholder="prometheus-placeholder-secret" \
  --dry-run=client -o yaml |
  kubeseal \
    --controller-name=$SEALED_SECRETS_CONTROLLER_NAME \
    --controller-namespace=$SEALED_SECRETS_CONTROLLER_NAMESPACE \
    --format=yaml \
    >"$OUTPUT_FILE"

# Add proper labels to the SealedSecret
cat <<EOF >"${OUTPUT_FILE}.tmp"
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: $SECRET_NAME
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: prometheus
    app.kubernetes.io/part-of: monitoring-stack
EOF

# Extract everything from spec: onwards from the generated file and append
sed -n '/^spec:/,$ p' "$OUTPUT_FILE" >>"${OUTPUT_FILE}.tmp"

# Replace the original file
mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"

echo -e "${GREEN}✓ Placeholder sealed secret created: $OUTPUT_FILE${NC}"
echo ""

# Show summary
echo -e "${BLUE}=== Summary ===${NC}"
echo -e "${GREEN}Created placeholder sealed secret${NC}"
echo -e "${YELLOW}  • File: $OUTPUT_FILE${NC}"
echo -e "${YELLOW}  • Contains: placeholder data (update when needed)${NC}"
echo ""

echo -e "${BLUE}=== Information ===${NC}"
echo -e "Prometheus is currently accessible at: ${GREEN}https://prometheus.home.cwbtech.net${NC}"
echo -e "No authentication is currently required"
echo ""
echo -e "${YELLOW}To add authentication in the future:${NC}"
echo -e "1. Update this script with actual secret prompts"
echo -e "2. Configure Prometheus to use the secrets"
echo -e "3. Update Istio VirtualService with authentication"
echo ""

echo -e "${BLUE}=== Next Steps ===${NC}"
echo -e "${YELLOW}1. Review the generated file: $OUTPUT_FILE${NC}"
echo -e "${YELLOW}2. Commit the file to git:${NC}"
echo -e "   ${BLUE}git add $OUTPUT_FILE${NC}"
echo -e "   ${BLUE}git commit -m \"Add Prometheus placeholder sealed secret\"${NC}"
echo -e "   ${BLUE}git push${NC}"
echo -e "${YELLOW}3. FluxCD will automatically deploy the secret${NC}"
echo ""
echo -e "${GREEN}✓ Sealed secret creation complete!${NC}"
