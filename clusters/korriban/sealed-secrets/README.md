# Sealed Secrets Helm Chart

This Helm chart deploys the [Bitnami Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) controller to your Kubernetes cluster.

## Introduction

Sealed Secrets is a Kubernetes controller and tool for one-way encrypted Secrets. The Sealed Secrets controller in the cluster automatically decrypts the encrypted secrets into regular Kubernetes Secrets.

## Prerequisites

- Kubernetes 1.16+
- Helm 3.0+

## Installing the Chart

To install the chart with the release name `sealed-secrets`:

```bash
helm install sealed-secrets ./aws/us-east-1/rp-eks-stg/sealed-secrets
```

## Certificate Management

### Understanding Sealed Secrets Certificates

Sealed Secrets uses a public/private key pair:

- The private key is used by the controller to decrypt secrets
- The public key is used by users to encrypt secrets

By default, the controller generates a key pair on first startup and stores it as a Secret in the same namespace.

### Fetching the Public Certificate

To encrypt secrets, you need the controller's public key:

```bash
# Save the public key to a file
kubeseal --fetch-cert > public-cert.pem

```

### Backing Up the Private Key

It's crucial to back up the private key for disaster recovery:

```bash
# Backup the private key
kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > sealed-secrets-key.yaml
```

### Rotating Certificates

To rotate the certificate:

```bash
# Generate a new key pair
openssl req -x509 -days 365 -nodes -newkey rsa:4096 -keyout tls.key -out tls.crt -subj "/CN=sealed-secret/O=sealed-secret"

# Create a new secret with the key pair
kubectl -n kube-system create secret tls sealed-secrets-key --cert=tls.crt --key=tls.key --dry-run=client -o yaml | kubectl apply -f -

# Restart the controller to use the new key
kubectl -n kube-system delete pod -l app.kubernetes.io/name=sealed-secrets
```

### Using Custom Certificates

To use your own certificates instead of letting the controller generate them:

```bash
# Create a secret with your certificates before installing the controller
kubectl -n kube-system create secret tls sealed-secrets-key --cert=tls.crt --key=tls.key
```

## Encrypting Secrets with Sealed Secrets

### Installing the kubeseal CLI

First, install the `kubeseal` CLI tool:

```bash
# For macOS
brew install kubeseal

# For Linux
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.19.5/kubeseal-0.19.5-linux-amd64.tar.gz
tar -xvzf kubeseal-0.19.5-linux-amd64.tar.gz
sudo install -m 755 kubeseal /usr/local/bin/kubeseal

# For Windows (using Chocolatey)
choco install kubeseal
```

### Basic Usage

1. Create a regular Kubernetes Secret manifest:

```yaml
# my-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
  namespace: default
type: Opaque
data:
  username: YWRtaW4= # base64 encoded "admin"
  password: cGFzc3dvcmQ= # base64 encoded "password"
```

2. Encrypt the Secret using kubeseal:

```bash
kubeseal --format yaml < my-secret.yaml > sealed-secret.yaml
```

3. Apply the SealedSecret to your cluster:

```bash
kubectl apply -f sealed-secret.yaml
```

### Creating Secrets from Literal Values

You can create a SealedSecret directly from literal values:

```bash
# Create a regular secret and pipe to kubeseal
kubectl create secret generic mysecret \
  --from-literal=username=admin \
  --from-literal=password=password \
  --dry-run=client -o yaml | \
  kubeseal --format yaml > sealed-secret.yaml
```

### Creating Secrets from Files

To create a secret from files:

```bash
# Create a secret from files
kubectl create secret generic mysecret \
  --from-file=./credentials.json \
  --from-file=./config.yaml \
  --dry-run=client -o yaml | \
  kubeseal --format yaml > sealed-secret.yaml
```

### Namespace-Specific Secrets

By default, a SealedSecret can only be decrypted in the same namespace it was sealed for:

```bash
kubeseal --format yaml --namespace production < my-secret.yaml > sealed-secret.yaml
```

### Cluster-Wide Secrets

To create a SealedSecret that can be deployed to any namespace:

```bash
kubeseal --format yaml --scope cluster-wide < my-secret.yaml > sealed-secret.yaml
```

### Using a Specific Certificate

If you need to use a specific public key:

```bash
# Fetch the certificate
kubeseal --fetch-cert > public-cert.pem

# Use the certificate for encryption
kubeseal --format yaml --cert public-cert.pem < my-secret.yaml > sealed-secret.yaml
```

### Encrypting Secrets for a Different Cluster

To encrypt secrets for a different cluster:

```bash
# Get the public key from the target cluster
kubeseal --fetch-cert --controller-name=sealed-secrets --controller-namespace=kube-system > target-cluster-cert.pem

# Encrypt using the target cluster's certificate
kubeseal --format yaml --cert target-cluster-cert.pem < my-secret.yaml > sealed-secret.yaml
```

## Troubleshooting

### Verifying Controller Status

```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets
```

### Checking Controller Logs

```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=sealed-secrets
```

### Common Issues

1. **Secret cannot be decrypted**: Ensure the SealedSecret was created for the correct namespace and using the correct certificate.

2. **Certificate mismatch**: If you've rotated certificates, older SealedSecrets might not decrypt. The controller keeps old keys by default, but you may need to restore from backup.

3. **Controller not starting**: Check for RBAC issues or certificate problems in the logs.
