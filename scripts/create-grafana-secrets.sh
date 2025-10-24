#!/bin/bash

# All-in-one script to create Grafana sealed secrets (both admin and basic auth)
# Run this from the root of your repository

set -e

# Configuration
BASIC_AUTH_USERNAME="grafana"
ADMIN_USERNAME="admin"
NAMESPACE="monitoring"
BASIC_AUTH_SECRET_NAME="grafana-basic-auth"
ADMIN_SECRET_NAME="grafana-admin-secret"
OUTPUT_FILE="apps/grafana/overlay/korriban/sealed-secrets.yaml"
TEMP_SECRET_FILE="temp-grafana-secret.yaml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔐 Creating Grafana Sealed Secrets (Both Admin & Basic Auth)${NC}"
echo "=============================================================="

# Check if we're in the repo root
if [ ! -d "apps/grafana" ]; then
  echo -e "${RED}❌ Please run this script from the root of your repository${NC}"
  echo "   Expected directory: apps/grafana"
  exit 1
fi

# Create the output directory if it doesn't exist
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Check if kubeseal is installed
if ! command -v kubeseal &>/dev/null; then
  echo -e "${RED}❌ kubeseal CLI not found. Please install it first:${NC}"
  echo "   brew install kubeseal"
  echo "   # or download from: https://github.com/bitnami-labs/sealed-secrets/releases"
  exit 1
fi

# Check if htpasswd is installed
if ! command -v htpasswd &>/dev/null; then
  echo -e "${RED}❌ htpasswd not found. Please install it first:${NC}"
  echo "   sudo apt-get install apache2-utils (Ubuntu/Debian)"
  echo "   brew install httpd (macOS)"
  exit 1
fi

# Check if sealed-secrets controller is running
if ! kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets | grep -q Running; then
  echo -e "${RED}❌ Sealed Secrets controller not found or not running${NC}"
  echo "   Please ensure sealed-secrets is deployed first"
  exit 1
fi

# Prompt for Grafana admin password
echo -e "${YELLOW}📝 Enter password for Grafana admin user ('${ADMIN_USERNAME}'):${NC}"
read -s ADMIN_PASSWORD

if [ -z "$ADMIN_PASSWORD" ]; then
  echo -e "${RED}❌ Admin password cannot be empty${NC}"
  exit 1
fi

# Prompt for basic auth password
echo -e "${YELLOW}📝 Enter password for basic auth user ('${BASIC_AUTH_USERNAME}'):${NC}"
read -s BASIC_AUTH_PASSWORD

if [ -z "$BASIC_AUTH_PASSWORD" ]; then
  echo -e "${RED}❌ Basic auth password cannot be empty${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Creating admin credentials secret...${NC}"

# Create admin credentials secret
cat >"$TEMP_SECRET_FILE" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: $ADMIN_SECRET_NAME
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: grafana
    app.kubernetes.io/part-of: monitoring-stack
type: Opaque
data:
  admin-user: $(echo -n "$ADMIN_USERNAME" | base64 -w 0)
  admin-password: $(echo -n "$ADMIN_PASSWORD" | base64 -w 0)
EOF

# Generate the sealed secret for admin credentials
kubeseal -f "$TEMP_SECRET_FILE" -o yaml \
  --controller-name sealed-secrets \
  --controller-namespace kube-system >"temp-admin-sealed-secret.yaml"

if [ $? -ne 0 ]; then
  echo -e "${RED}❌ Failed to create admin sealed secret${NC}"
  rm -f "$TEMP_SECRET_FILE"
  exit 1
fi

# Extract encrypted admin data
ENCRYPTED_ADMIN_USER=$(grep "admin-user:" temp-admin-sealed-secret.yaml | awk '{print $2}')
ENCRYPTED_ADMIN_PASSWORD=$(grep "admin-password:" temp-admin-sealed-secret.yaml | awk '{print $2}')

echo -e "${GREEN}✅ Generating htpasswd data...${NC}"

# Generate htpasswd entry
HTPASSWD_DATA=$(htpasswd -nb "$BASIC_AUTH_USERNAME" "$BASIC_AUTH_PASSWORD")

if [ $? -ne 0 ]; then
  echo -e "${RED}❌ Failed to generate htpasswd data${NC}"
  exit 1
fi

# Base64 encode the htpasswd data
HTPASSWD_BASE64=$(echo -n "$HTPASSWD_DATA" | base64 -w 0)

echo -e "${GREEN}✅ Creating basic auth secret...${NC}"

# Create the basic auth secret file
cat >"$TEMP_SECRET_FILE" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: $BASIC_AUTH_SECRET_NAME
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: grafana
    app.kubernetes.io/part-of: monitoring-stack
type: Opaque
data:
  auth: $HTPASSWD_BASE64
EOF

# Generate the sealed secret for basic auth
kubeseal -f "$TEMP_SECRET_FILE" -o yaml \
  --controller-name sealed-secrets \
  --controller-namespace kube-system >"temp-auth-sealed-secret.yaml"

if [ $? -ne 0 ]; then
  echo -e "${RED}❌ Failed to create basic auth sealed secret${NC}"
  rm -f "$TEMP_SECRET_FILE" temp-admin-sealed-secret.yaml
  exit 1
fi

# Extract encrypted auth data
ENCRYPTED_AUTH=$(grep "auth:" temp-auth-sealed-secret.yaml | awk '{print $2}')

echo -e "${GREEN}✅ Creating sealed-secrets.yaml file...${NC}"

# Create the final sealed secrets file
cat >"$OUTPUT_FILE" <<EOF
---
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: $ADMIN_SECRET_NAME
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: grafana
    app.kubernetes.io/part-of: monitoring-stack
spec:
  encryptedData:
    admin-user: "$ENCRYPTED_ADMIN_USER"
    admin-password: "$ENCRYPTED_ADMIN_PASSWORD"
  template:
    metadata:
      name: $ADMIN_SECRET_NAME
      namespace: $NAMESPACE
      labels:
        app.kubernetes.io/name: grafana
        app.kubernetes.io/part-of: monitoring-stack
    type: Opaque
---
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: $BASIC_AUTH_SECRET_NAME
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: grafana
    app.kubernetes.io/part-of: monitoring-stack
spec:
  encryptedData:
    auth: "$ENCRYPTED_AUTH"
  template:
    metadata:
      name: $BASIC_AUTH_SECRET_NAME
      namespace: $NAMESPACE
      labels:
        app.kubernetes.io/name: grafana
        app.kubernetes.io/part-of: monitoring-stack
    type: Opaque
EOF

if [ -f "$OUTPUT_FILE" ] && [ -s "$OUTPUT_FILE" ]; then
  echo -e "${GREEN}🎉 Success! Both sealed secrets have been created!${NC}"
  echo ""
  echo -e "${YELLOW}📋 Summary:${NC}"
  echo "   • File created: $OUTPUT_FILE"
  echo "   • Admin username: $ADMIN_USERNAME"
  echo "   • Admin password: [hidden]"
  echo "   • Basic auth username: $BASIC_AUTH_USERNAME"
  echo "   • Basic auth password: [hidden]"
  echo ""
  echo -e "${YELLOW}🚀 Next steps:${NC}"
  echo "   1. Review the file: $OUTPUT_FILE"
  echo "   2. Commit your changes: git add $OUTPUT_FILE"
  echo "   3. Deploy: git commit -m 'Add Grafana sealed secrets' && git push"
  echo ""
  echo -e "${GREEN}💡 Your Grafana will have dual authentication:${NC}"
  echo "   • Basic auth (Traefik): $BASIC_AUTH_USERNAME/[your password]"
  echo "   • Grafana login: $ADMIN_USERNAME/[your password]"
else
  echo -e "${RED}❌ Failed to create sealed secret file${NC}"
  echo "   Please check permissions and try again"
fi

# Clean up temporary files
echo -e "${YELLOW}🧹 Cleaning up temporary files...${NC}"
rm -f "$TEMP_SECRET_FILE" temp-admin-sealed-secret.yaml temp-auth-sealed-secret.yaml

echo -e "${GREEN}✅ Done!${NC}"
