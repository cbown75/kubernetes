#!/bin/bash
# cloudflared-sealed-secret.sh - Fixed version that addresses template structure issues
# Creates properly structured sealed secrets for Cloudflare tunnel authentication

set -euo pipefail

# Configuration
NAMESPACE="cloudflare-tunnel"
SECRET_NAME="cloudflare-tunnel-cloudflared"
CONTROLLER_NAME="sealed-secrets"
CONTROLLER_NAMESPACE="kube-system"
OUTPUT_FILE="clusters/korriban/apps/cloudflared/sealed-secret.yaml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Temp files
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
  exit 1
}

# Check prerequisites
check_prerequisites() {
  log_info "Checking prerequisites..."

  command -v kubectl >/dev/null 2>&1 || log_error "kubectl not found"
  command -v kubeseal >/dev/null 2>&1 || log_error "kubeseal not found"

  kubectl cluster-info >/dev/null 2>&1 || log_error "Cannot connect to cluster"

  kubectl get deployment "$CONTROLLER_NAME" -n "$CONTROLLER_NAMESPACE" >/dev/null 2>&1 ||
    log_error "Sealed secrets controller not found: $CONTROLLER_NAME in $CONTROLLER_NAMESPACE"

  log_info "Prerequisites check passed"
}

# Get tunnel credentials
get_credentials() {
  log_info "Enter Cloudflare tunnel credentials:"

  read -p "Account ID: " ACCOUNT_ID
  [ -z "$ACCOUNT_ID" ] && log_error "Account ID cannot be empty"

  read -p "Tunnel ID: " TUNNEL_ID
  [ -z "$TUNNEL_ID" ] && log_error "Tunnel ID cannot be empty"

  read -p "Tunnel Name: " TUNNEL_NAME
  [ -z "$TUNNEL_NAME" ] && log_error "Tunnel Name cannot be empty"

  read -s -p "Tunnel Secret: " TUNNEL_SECRET
  echo
  [ -z "$TUNNEL_SECRET" ] && log_error "Tunnel Secret cannot be empty"
}

# Create credentials JSON
create_credentials_json() {
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
}

# Create base secret with proper structure
create_base_secret() {
  local secret_file="$1"

  log_info "Creating base Kubernetes secret with proper structure..."

  cat >"$secret_file" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: $SECRET_NAME
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: cloudflared
    app.kubernetes.io/part-of: cloudflare-tunnel
type: Opaque
stringData:
  credentials.json: |
$CREDENTIALS_JSON
EOF

  # Validate the secret
  kubectl apply --dry-run=client -f "$secret_file" >/dev/null 2>&1 ||
    log_error "Generated secret failed validation"

  log_info "Base secret created and validated"
}

# Seal the secret with complete template
seal_secret() {
  local secret_file="$1"
  local sealed_file="$2"

  log_info "Sealing secret with file-based workflow..."

  # Use file-based workflow to avoid pipe truncation issues
  kubeseal -f "$secret_file" \
    -w "$sealed_file" \
    --controller-name="$CONTROLLER_NAME" \
    --controller-namespace="$CONTROLLER_NAMESPACE" \
    --format yaml || log_error "Failed to seal secret"

  # Verify sealed secret has template section
  if ! grep -q "template:" "$sealed_file"; then
    log_error "Sealed secret missing template section - this will cause authentication failures!"
  fi

  if ! grep -q "type: Opaque" "$sealed_file"; then
    log_error "Sealed secret missing 'type: Opaque' - this will cause authentication failures!"
  fi

  log_info "Secret sealed successfully with complete template"
}

# Validate sealed secret structure
validate_sealed_secret() {
  local sealed_file="$1"

  log_info "Validating sealed secret structure..."

  # Check required sections
  local checks=(
    "apiVersion: bitnami.com/v1alpha1"
    "kind: SealedSecret"
    "encryptedData:"
    "credentials.json:"
    "template:"
    "type: Opaque"
  )

  for check in "${checks[@]}"; do
    if ! grep -q "$check" "$sealed_file"; then
      log_error "Missing required field: $check"
    fi
  done

  log_info "Sealed secret validation passed"
}

# Main execution
main() {
  echo "========================================"
  echo "Cloudflared Sealed Secret Generator"
  echo "========================================"
  echo "Namespace: $NAMESPACE"
  echo "Secret: $SECRET_NAME"
  echo "Output: $OUTPUT_FILE"
  echo "========================================"
  echo

  check_prerequisites
  get_credentials
  create_credentials_json

  # Create directory if needed
  mkdir -p "$(dirname "$OUTPUT_FILE")"

  local secret_file="$TEMP_DIR/secret.yaml"
  local sealed_file="$TEMP_DIR/sealed.yaml"

  create_base_secret "$secret_file"
  seal_secret "$secret_file" "$sealed_file"
  validate_sealed_secret "$sealed_file"

  # Copy to final location
  cp "$sealed_file" "$OUTPUT_FILE"

  log_info "✅ SUCCESS! Sealed secret created: $OUTPUT_FILE"
  echo
  log_info "Next steps:"
  echo "  1. Review the file: cat $OUTPUT_FILE"
  echo "  2. Commit to git: git add $OUTPUT_FILE && git commit -m 'Fix Cloudflare tunnel sealed secret'"
  echo "  3. Deploy: git push"
  echo
  log_info "The sealed secret now has the proper template structure to fix your authentication issues!"
}

main "$@"
