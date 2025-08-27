#!/bin/zsh

echo "Enter your Grafana service account API key:"
read -s API_KEY

if [ -z "$API_KEY" ]; then
  echo "❌ API key cannot be empty"
  exit 1
fi

echo "✅ Creating sealed secret for Grafana MCP server..."

kubectl create secret generic grafana-mcp-api-key \
  --from-literal=api-key="$API_KEY" \
  --namespace=monitoring \
  --dry-run=client -o yaml |
  kubeseal -o yaml \
    --controller-name=sealed-secrets \
    --controller-namespace=kube-system >clusters/korriban/apps/grafana-mcp/sealed-secret.yaml

echo "✅ Created sealed secret at clusters/korriban/apps/grafana-mcp/sealed-secret.yaml"
