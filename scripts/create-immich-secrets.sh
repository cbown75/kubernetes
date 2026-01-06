#!/bin/bash
set -euo pipefail

# Check prerequisites
command -v kubectl >/dev/null 2>&1 || { echo "kubectl required"; exit 1; }
command -v kubeseal >/dev/null 2>&1 || { echo "kubeseal required"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT_FILE="$REPO_ROOT/apps/immich/overlay/korriban/sealed-secrets.yaml"

echo "=== Immich Secrets Generator ==="
echo

read -p "PostgreSQL username [immich]: " DB_USERNAME
DB_USERNAME=${DB_USERNAME:-immich}

read -sp "PostgreSQL password: " DB_PASSWORD
echo

read -sp "JWT secret (press Enter to generate): " JWT_SECRET
echo
if [ -z "$JWT_SECRET" ]; then
    JWT_SECRET=$(openssl rand -base64 32)
    echo "Generated JWT secret"
fi

# Create temp secret
kubectl create secret generic immich-secrets \
  --namespace=immich \
  --from-literal=db-username="$DB_USERNAME" \
  --from-literal=db-password="$DB_PASSWORD" \
  --from-literal=jwt-secret="$JWT_SECRET" \
  --dry-run=client -o yaml > /tmp/immich-secret.yaml

# Seal it
kubeseal --format yaml < /tmp/immich-secret.yaml > "$OUTPUT_FILE"
rm /tmp/immich-secret.yaml

echo
echo "Sealed secret created: $OUTPUT_FILE"
echo "Remember to create the 'immich' database on PostgreSQL at 10.10.7.200"
