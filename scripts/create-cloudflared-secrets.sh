#!/bin/bash
# Fixed Cloudflared sealed secret script that ensures proper template with type: Opaque

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

  # Check for sealed secrets controller
  if ! kubectl get pods -n "$CONTROLLER_NAMESPACE" -l app.kubernetes.io/name=sealed-secrets >/dev/null 2>&1; then
    log_error "Sealed secrets controller not found in $CONTROLLER_NAMESPACE"
  fi

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

  kubectl apply --dry-run=client -f "$secret_file" >/dev/null 2>&1 ||
    log_error "Generated secret failed validation"

  log_info "Base secret created and validated"
}

# Seal secret and fix template
seal_secret_with_template_fix() {
  local secret_file="$1"
  local sealed_file="$2"

  log_info "Sealing secret with file-based workflow..."

  # Use file-based workflow
  kubeseal -f "$secret_file" \
    -w "$sealed_file" \
    --controller-name="$CONTROLLER_NAME" \
    --controller-namespace="$CONTROLLER_NAMESPACE" \
    --format yaml || log_error "Failed to seal secret"

  log_info "Secret sealed - now fixing template section..."

  # CRITICAL FIX: Add type: Opaque to template if missing
  local temp_file="$TEMP_DIR/fixed_sealed.yaml"

  # Use awk to add type: Opaque to template section
  awk '
    /^  template:$/ {
        print $0
        getline
        print $0
        if ($0 ~ /metadata:/) {
            # Add type: Opaque before metadata
            print "    type: Opaque"
        }
        next
    }
    { print }
    ' "$sealed_file" >"$temp_file"

  # If that didn't work, try a more direct approach
  if ! grep -q "type: Opaque" "$temp_file"; then
    log_warn "First fix attempt failed, trying direct template replacement..."

    # Replace the entire template section
    sed '/^  template:/,/^[^ ]/{
            /^  template:/!{
                /^[^ ]/!d
            }
        }' "$sealed_file" >"$temp_file"

    # Add proper template section
    cat >>"$temp_file" <<EOF
  template:
    type: Opaque
    metadata:
      name: $SECRET_NAME
      namespace: $NAMESPACE
      labels:
        app.kubernetes.io/name: cloudflared
        app.kubernetes.io/part-of: cloudflare-tunnel
EOF
  fi

  mv "$temp_file" "$sealed_file"

  log_info "Template section fixed"
}

# Validate sealed secret structure
validate_sealed_secret() {
  local sealed_file="$1"

  log_info "Validating sealed secret structure..."

  # Check required sections
  local missing_items=()

  grep -q "apiVersion: bitnami.com/v1alpha1" "$sealed_file" || missing_items+=("apiVersion")
  grep -q "kind: SealedSecret" "$sealed_file" || missing_items+=("kind")
  grep -q "encryptedData:" "$sealed_file" || missing_items+=("encryptedData")
  grep -q "credentials.json:" "$sealed_file" || missing_items+=("credentials.json")
  grep -q "template:" "$sealed_file" || missing_items+=("template")
  grep -q "type: Opaque" "$sealed_file" || missing_items+=("type: Opaque")

  if [ ${#missing_items[@]} -ne 0 ]; then
    log_error "Missing required fields: ${missing_items[*]}"
  fi

  log_info "✅ Sealed secret validation passed - template has type: Opaque"
}

# Main execution
main() {
  echo "========================================"
  echo "Cloudflared Sealed Secret Generator"
  echo "Fixed Template Type Version"
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
  seal_secret_with_template_fix "$secret_file" "$sealed_file"
  validate_sealed_secret "$sealed_file"

  # Copy to final location
  cp "$sealed_file" "$OUTPUT_FILE"

  log_info "✅ SUCCESS! Fixed sealed secret created: $OUTPUT_FILE"
  echo
  log_info "Generated sealed secret now includes:"
  echo "  ✅ Complete template section"
  echo "  ✅ type: Opaque in template"
  echo "  ✅ Proper metadata structure"
  echo
  log_info "Next steps:"
  echo "  1. Review the file: cat $OUTPUT_FILE"
  echo "  2. Commit to git: git add $OUTPUT_FILE && git commit -m 'Fix Cloudflare sealed secret template'"
  echo "  3. Deploy: git push"
  echo
  echo "This should fix the authentication issues caused by missing template type!"
}

main "$@"
