#!/bin/bash
# Create GitHub PAT secret for private repo access
# Replace YOUR_GITHUB_PAT with your actual Personal Access Token

# Prompt for token if not provided
if [ -z "$GITHUB_TOKEN" ]; then
  echo "Enter your GitHub Personal Access Token:"
  read -s GITHUB_TOKEN
fi

kubectl create secret generic github-private-token \
  --from-literal=username=git \
  --from-literal=password=$GITHUB_TOKEN \
  --namespace=flux-system \
  --context=admin@korriban \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secret created successfully!"
