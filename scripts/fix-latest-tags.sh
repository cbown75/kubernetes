#!/bin/bash
# Fix container images using :latest tag
# This script helps identify current versions and apply fixes

set -e

REPO_ROOT="/Users/cbown75/git/kubernetes"
cd "$REPO_ROOT"

echo "================================================================"
echo "Container Image :latest Tag Remediation Script"
echo "================================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check if kubectl is available
check_kubectl() {
  if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}ERROR: kubectl not found${NC}"
    echo "This script needs kubectl to check current running versions"
    exit 1
  fi
}

# Function to check current context
check_context() {
  CURRENT_CONTEXT=$(kubectl config current-context)
  echo -e "${BLUE}Current kubectl context: ${YELLOW}$CURRENT_CONTEXT${NC}"
  echo ""
}

echo -e "${YELLOW}CRITICAL PRIORITY: Synology CSI Driver${NC}"
echo "========================================"
echo ""

check_kubectl
check_context

# Check Synology CSI current version
echo "Checking current Synology CSI driver version..."
SYNOLOGY_IMAGE=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=synology-csi-driver \
  -o jsonpath='{.items[0].spec.containers[?(@.name=="synology-csi-driver")].image}' 2>/dev/null || echo "NOT FOUND")

if [ "$SYNOLOGY_IMAGE" = "NOT FOUND" ]; then
  echo -e "${RED}Could not find running Synology CSI driver pod${NC}"
  echo "The driver may not be deployed yet, or the label selector is incorrect."
  echo ""
  echo "Recommended action: Use the default from values.yaml (20250814)"
else
  echo -e "${GREEN}Current running image: $SYNOLOGY_IMAGE${NC}"

  # Extract tag
  CURRENT_TAG=$(echo "$SYNOLOGY_IMAGE" | cut -d: -f2)
  echo -e "Current tag: ${YELLOW}$CURRENT_TAG${NC}"
  echo ""

  if [ "$CURRENT_TAG" = "latest" ]; then
    echo -e "${RED}WARNING: Driver is currently using :latest tag!${NC}"
    echo "This is unstable for production storage."
    echo ""
    echo "Checking image digest to identify actual version..."
    DIGEST=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=synology-csi-driver \
      -o jsonpath='{.items[0].status.containerStatuses[?(@.name=="synology-csi-driver")].imageID}' 2>/dev/null || echo "NOT FOUND")

    if [ "$DIGEST" != "NOT FOUND" ]; then
      echo -e "Current digest: ${BLUE}$DIGEST${NC}"
      echo ""
      echo "Recommendation: Pin to this digest or to dated tag '20250814'"
    fi
  fi
fi

echo ""
echo -e "${YELLOW}File to fix: ${NC}clusters/korriban/infrastructure/storage/release.yaml"
echo "Lines 54-57"
echo ""
echo "Current configuration:"
echo "  csiDriver:"
echo "    image:"
echo "      repository: ghcr.io/cbown75/synology-csi"
echo "      tag: latest"
echo "      pullPolicy: Always"
echo ""
echo "Recommended change:"
echo "  csiDriver:"
echo "    image:"
echo "      repository: ghcr.io/cbown75/synology-csi"
echo "      tag: \"20250814\"  # Or current stable version"
echo "      pullPolicy: IfNotPresent"
echo ""

read -p "Would you like to see the available tags for this image? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "Checking available tags from ghcr.io..."

  if command -v crane &> /dev/null; then
    echo ""
    echo "Available tags:"
    crane ls ghcr.io/cbown75/synology-csi 2>/dev/null || echo "Could not fetch tags (might need authentication)"
  elif command -v skopeo &> /dev/null; then
    echo ""
    echo "Available tags:"
    skopeo list-tags docker://ghcr.io/cbown75/synology-csi 2>/dev/null || echo "Could not fetch tags (might need authentication)"
  else
    echo ""
    echo "Install 'crane' or 'skopeo' to list available tags:"
    echo "  brew install crane"
    echo "  brew install skopeo"
  fi
fi

echo ""
echo "================================================================"
echo -e "${YELLOW}IMPORTANT PRIORITY: Nebula Sync${NC}"
echo "================================================================"
echo ""

# Check nebula-sync deployments
echo "Checking nebula-sync deployments..."
NEBULA_IMAGES=$(kubectl get deployments -n default -l app=nebula-sync \
  -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.template.spec.containers[0].image}{"\n"}{end}' 2>/dev/null || echo "")

if [ -z "$NEBULA_IMAGES" ]; then
  echo -e "${YELLOW}No nebula-sync deployments found in default namespace${NC}"
  echo "They may be in a different namespace or not yet deployed."
else
  echo "$NEBULA_IMAGES" | while read name image; do
    echo -e "${GREEN}$name${NC}: $image"
  done
fi

echo ""
echo "Files to fix (3 files):"
echo "  1. apps/nebula-sync-pihole1/base/deployment.yaml"
echo "  2. apps/nebula-sync-pihole3/base/deployment.yaml"
echo "  3. apps/nebula-sync-pihole5/base/deployment.yaml"
echo ""
echo "Current configuration in each file:"
echo "  containers:"
echo "    - name: nebula-sync"
echo "      image: ghcr.io/lovelaze/nebula-sync:latest"
echo ""
echo "Recommended change (check upstream for available versions):"
echo "  containers:"
echo "    - name: nebula-sync"
echo "      image: ghcr.io/lovelaze/nebula-sync:v1.0.0  # or pinned SHA"
echo ""

read -p "Check available tags for nebula-sync? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "Checking available tags from ghcr.io..."

  if command -v crane &> /dev/null; then
    echo ""
    echo "Available tags:"
    crane ls ghcr.io/lovelaze/nebula-sync 2>/dev/null || echo "Could not fetch tags (might need authentication)"
  elif command -v skopeo &> /dev/null; then
    echo ""
    echo "Available tags:"
    skopeo list-tags docker://ghcr.io/lovelaze/nebula-sync 2>/dev/null || echo "Could not fetch tags (might need authentication)"
  else
    echo ""
    echo "Install 'crane' or 'skopeo' to list available tags:"
    echo "  brew install crane"
    echo "  brew install skopeo"
  fi
fi

echo ""
echo "================================================================"
echo "NEXT STEPS"
echo "================================================================"
echo ""
echo "1. Review the IMAGE_AUDIT_REPORT.md for complete details"
echo "2. Pin synology-csi to a specific version (CRITICAL)"
echo "3. Research and pin nebula-sync to a version or SHA"
echo "4. Test changes with: kubectl apply --dry-run=client -f <file>"
echo "5. Commit and push changes to trigger FluxCD reconciliation"
echo "6. Monitor with: flux get kustomizations -A"
echo "7. Verify Renovate detects the pinned versions"
echo ""
echo "For detailed remediation instructions, see:"
echo "  ${REPO_ROOT}/IMAGE_AUDIT_REPORT.md"
echo ""
