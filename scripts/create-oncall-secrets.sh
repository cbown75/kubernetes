#!/bin/bash

# Create sealed secrets for Grafana OnCall
# Run this from the root of your repository

set -e

# Configuration
NAMESPACE="oncall"
OUTPUT_FILE="apps/oncall/overlay/korriban/sealed-secrets.yaml"
TEMP_SECRET_FILE="temp-oncall-secret.yaml"

# Secret names matching what the Helm chart expects
MARIADB_SECRET_NAME="oncall-mariadb"
RABBITMQ_SECRET_NAME="oncall-rabbitmq"
REDIS_SECRET_NAME="oncall-redis"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔐 Creating Grafana OnCall Sealed Secrets${NC}"
echo "=============================================="

# Check if we're in the repo root
if [ ! -d "apps/oncall" ]; then
  echo -e "${RED}❌ Please run this script from the root of your repository${NC}"
  echo "   Expected directory: apps/oncall"
  exit 1
fi

# Create the output directory if it doesn't exist
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Check if kubeseal is installed
if ! command -v kubeseal &>/dev/null; then
  echo -e "${RED}❌ kubeseal CLI not found. Please install it first:${NC}"
  echo "   brew install kubeseal"
  exit 1
fi

# Check if sealed-secrets controller is running
if ! kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets | grep -q Running; then
  echo -e "${RED}❌ Sealed Secrets controller not found or not running${NC}"
  exit 1
fi

# Generate random passwords or prompt
generate_password() {
  openssl rand -base64 24 | tr -d '/+=' | head -c 24
}

echo -e "${YELLOW}📝 Would you like to generate random passwords? (y/n)${NC}"
read -r GENERATE_RANDOM

if [ "$GENERATE_RANDOM" = "y" ] || [ "$GENERATE_RANDOM" = "Y" ]; then
  MARIADB_ROOT_PASSWORD=$(generate_password)
  MARIADB_PASSWORD=$(generate_password)
  RABBITMQ_PASSWORD=$(generate_password)
  REDIS_PASSWORD=$(generate_password)
  echo -e "${GREEN}✅ Random passwords generated${NC}"
else
  echo -e "${YELLOW}📝 Enter MariaDB root password:${NC}"
  read -s MARIADB_ROOT_PASSWORD
  echo -e "${YELLOW}📝 Enter MariaDB oncall user password:${NC}"
  read -s MARIADB_PASSWORD
  echo -e "${YELLOW}📝 Enter RabbitMQ password:${NC}"
  read -s RABBITMQ_PASSWORD
  echo -e "${YELLOW}📝 Enter Redis password:${NC}"
  read -s REDIS_PASSWORD
fi

# Validate passwords
for pw in "$MARIADB_ROOT_PASSWORD" "$MARIADB_PASSWORD" "$RABBITMQ_PASSWORD" "$REDIS_PASSWORD"; do
  if [ -z "$pw" ]; then
    echo -e "${RED}❌ All passwords are required${NC}"
    exit 1
  fi
done

echo -e "${GREEN}✅ Creating MariaDB secret...${NC}"

# Create MariaDB secret (matches Bitnami chart format)
cat >"$TEMP_SECRET_FILE" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: $MARIADB_SECRET_NAME
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: oncall
    app.kubernetes.io/part-of: monitoring-stack
type: Opaque
data:
  mariadb-root-password: $(echo -n "$MARIADB_ROOT_PASSWORD" | base64 -w 0)
  mariadb-password: $(echo -n "$MARIADB_PASSWORD" | base64 -w 0)
EOF

kubeseal -f "$TEMP_SECRET_FILE" -o yaml \
  --controller-name sealed-secrets \
  --controller-namespace kube-system >"temp-mariadb-sealed.yaml"

ENCRYPTED_MARIADB_ROOT=$(grep "mariadb-root-password:" temp-mariadb-sealed.yaml | awk '{print $2}')
ENCRYPTED_MARIADB_PASSWORD=$(grep "mariadb-password:" temp-mariadb-sealed.yaml | awk '{print $2}')

echo -e "${GREEN}✅ Creating RabbitMQ secret...${NC}"

# Create RabbitMQ secret (matches Bitnami chart format)
cat >"$TEMP_SECRET_FILE" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: $RABBITMQ_SECRET_NAME
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: oncall
    app.kubernetes.io/part-of: monitoring-stack
type: Opaque
data:
  rabbitmq-password: $(echo -n "$RABBITMQ_PASSWORD" | base64 -w 0)
  rabbitmq-erlang-cookie: $(echo -n "$(generate_password)" | base64 -w 0)
EOF

kubeseal -f "$TEMP_SECRET_FILE" -o yaml \
  --controller-name sealed-secrets \
  --controller-namespace kube-system >"temp-rabbitmq-sealed.yaml"

ENCRYPTED_RABBITMQ_PASSWORD=$(grep "rabbitmq-password:" temp-rabbitmq-sealed.yaml | awk '{print $2}')
ENCRYPTED_RABBITMQ_COOKIE=$(grep "rabbitmq-erlang-cookie:" temp-rabbitmq-sealed.yaml | awk '{print $2}')

echo -e "${GREEN}✅ Creating Redis secret...${NC}"

# Create Redis secret (matches Bitnami chart format)
cat >"$TEMP_SECRET_FILE" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: $REDIS_SECRET_NAME
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: oncall
    app.kubernetes.io/part-of: monitoring-stack
type: Opaque
data:
  redis-password: $(echo -n "$REDIS_PASSWORD" | base64 -w 0)
EOF

kubeseal -f "$TEMP_SECRET_FILE" -o yaml \
  --controller-name sealed-secrets \
  --controller-namespace kube-system >"temp-redis-sealed.yaml"

ENCRYPTED_REDIS_PASSWORD=$(grep "redis-password:" temp-redis-sealed.yaml | awk '{print $2}')

echo -e "${GREEN}✅ Creating sealed-secrets.yaml file...${NC}"

# Create the final sealed secrets file
cat >"$OUTPUT_FILE" <<EOF
---
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: $MARIADB_SECRET_NAME
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: oncall
    app.kubernetes.io/part-of: monitoring-stack
spec:
  encryptedData:
    mariadb-root-password: "$ENCRYPTED_MARIADB_ROOT"
    mariadb-password: "$ENCRYPTED_MARIADB_PASSWORD"
  template:
    metadata:
      name: $MARIADB_SECRET_NAME
      namespace: $NAMESPACE
      labels:
        app.kubernetes.io/name: oncall
        app.kubernetes.io/part-of: monitoring-stack
    type: Opaque
---
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: $RABBITMQ_SECRET_NAME
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: oncall
    app.kubernetes.io/part-of: monitoring-stack
spec:
  encryptedData:
    rabbitmq-password: "$ENCRYPTED_RABBITMQ_PASSWORD"
    rabbitmq-erlang-cookie: "$ENCRYPTED_RABBITMQ_COOKIE"
  template:
    metadata:
      name: $RABBITMQ_SECRET_NAME
      namespace: $NAMESPACE
      labels:
        app.kubernetes.io/name: oncall
        app.kubernetes.io/part-of: monitoring-stack
    type: Opaque
---
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: $REDIS_SECRET_NAME
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: oncall
    app.kubernetes.io/part-of: monitoring-stack
spec:
  encryptedData:
    redis-password: "$ENCRYPTED_REDIS_PASSWORD"
  template:
    metadata:
      name: $REDIS_SECRET_NAME
      namespace: $NAMESPACE
      labels:
        app.kubernetes.io/name: oncall
        app.kubernetes.io/part-of: monitoring-stack
    type: Opaque
EOF

if [ -f "$OUTPUT_FILE" ] && [ -s "$OUTPUT_FILE" ]; then
  echo -e "${GREEN}🎉 Success! Sealed secrets created!${NC}"
  echo ""
  echo -e "${YELLOW}📋 Summary:${NC}"
  echo "   • File created: $OUTPUT_FILE"
  echo "   • MariaDB secret: $MARIADB_SECRET_NAME"
  echo "   • RabbitMQ secret: $RABBITMQ_SECRET_NAME"
  echo "   • Redis secret: $REDIS_SECRET_NAME"
  echo ""
  echo -e "${YELLOW}🚀 Next steps:${NC}"
  echo "   1. Update apps/oncall/base/helmrelease.yaml to use existingSecret"
  echo "   2. Update apps/oncall/overlay/korriban/kustomization.yaml to include sealed-secrets.yaml"
  echo "   3. Commit and push changes"
else
  echo -e "${RED}❌ Failed to create sealed secret file${NC}"
fi

# Clean up temporary files
echo -e "${YELLOW}🧹 Cleaning up temporary files...${NC}"
rm -f "$TEMP_SECRET_FILE" temp-mariadb-sealed.yaml temp-rabbitmq-sealed.yaml temp-redis-sealed.yaml

echo -e "${GREEN}✅ Done!${NC}"
