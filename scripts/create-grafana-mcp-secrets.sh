#!/bin/zsh

# Create Grafana MCP API key sealed secret
echo "Enter your Grafana service account API key:"
read -s API_KEY

kubectl create secret generic grafana-mcp-api-key \
  --from-literal=api-key="$API_KEY" \
  --namespace=monitoring \
  --controller-name sealed-secrets \
  --controller-namespace kube-system \
  --dry-run=client -o yaml |
  kubeseal -o yaml >clusters/korriban/apps/grafana-mcp/sealed-secret.yaml

echo "✅ Created sealed secret for Grafana MCP server"
