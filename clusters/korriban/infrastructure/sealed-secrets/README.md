# Sealed Secrets

Bitnami Sealed Secrets controller for encrypting Kubernetes secrets that can be safely stored in Git repositories.

## Overview

Sealed Secrets provides a way to encrypt Kubernetes secrets using asymmetric cryptography. The encrypted secrets (SealedSecrets) can be safely committed to Git, and only the cluster with the corresponding private key can decrypt them.

## How It Works

1. **Public Key Encryption**: Secrets are encrypted using a public key from the cluster
2. **Safe Storage**: Encrypted SealedSecrets can be stored in Git repositories
3. **Automatic Decryption**: The controller automatically decrypts SealedSecrets into regular Secrets
4. **Namespace Binding**: Secrets are bound to specific namespaces by default

## Architecture

- **Controller**: Runs in `kube-system` namespace, manages encryption/decryption
- **Private Key**: Stored securely in the cluster, used for decryption
- **Public Key**: Can be shared, used for encryption with `kubeseal` CLI

## Installation Status

The Sealed Secrets controller is installed via FluxCD and includes:

- Controller deployment in `kube-system` namespace
- RBAC permissions for secret management
- Service for `kubeseal` CLI communication
- Automatic key generation and rotation

## Prerequisites

Install the `kubeseal` CLI tool:

```bash
# Download latest release
KUBESEAL_VERSION='0.24.0'
wget "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"
tar -xvzf kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal

# Verify installation
kubeseal --version
```

## Creating Sealed Secrets

### Method 1: From Raw Secret YAML

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

### Method 2: From Literal Values

Create a SealedSecret directly from literal values:

```bash
# Create and encrypt in one command
kubectl create secret generic mysecret \
  --from-literal=username=admin \
  --from-literal=password=password \
  --dry-run=client -o yaml | \
  kubeseal --format yaml > sealed-secret.yaml
```

### Method 3: From Files

Create a secret from files:

```bash
# Create secret from files
kubectl create secret generic mysecret \
  --from-file=./credentials.json \
  --from-file=./config.yaml \
  --dry-run=client -o yaml | \
  kubeseal --format yaml > sealed-secret.yaml
```

## Scope and Security Models

### Namespace-Specific (Default)

By default, SealedSecrets can only be decrypted in the same namespace:

```bash
kubeseal --format yaml --namespace production < my-secret.yaml > sealed-secret.yaml
```

### Cluster-Wide Secrets

Create a SealedSecret that can be deployed to any namespace:

```bash
kubeseal --format yaml --scope cluster-wide < my-secret.yaml > sealed-secret.yaml
```

### Namespace-Wide Secrets

Create a SealedSecret that can be used by any secret name within a namespace:

```bash
kubeseal --format yaml --scope namespace-wide < my-secret.yaml > sealed-secret.yaml
```

## Advanced Usage

### Using Specific Certificate

If you need to use a specific public key:

```bash
# Fetch the certificate
kubeseal --fetch-cert > public-cert.pem

# Use the certificate for encryption
kubeseal --format yaml --cert public-cert.pem < my-secret.yaml > sealed-secret.yaml
```

### Encrypting for Different Cluster

To encrypt secrets for a different cluster:

```bash
# Get the public key from the target cluster
kubeseal --fetch-cert --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system > target-cluster-cert.pem

# Encrypt using the target cluster's certificate
kubeseal --format yaml --cert target-cluster-cert.pem < my-secret.yaml > sealed-secret.yaml
```

### Raw Mode (for CI/CD)

Encrypt individual secret values:

```bash
# Encrypt a single value
echo -n mypassword | kubeseal --raw --from-file=/dev/stdin --name mysecret --namespace default

# Use in CI/CD pipelines
PASSWORD=$(echo -n "$SECRET_VALUE" | kubeseal --raw --from-file=/dev/stdin --name mysecret --namespace default)
```

## Common Use Cases

### Database Credentials

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: database-credentials
  namespace: production
type: Opaque
stringData:
  username: dbuser
  password: supersecretpassword
  host: database.internal.com
  port: "5432"
```

Encrypt with:

```bash
kubectl create secret generic database-credentials \
  --from-literal=username=dbuser \
  --from-literal=password=supersecretpassword \
  --from-literal=host=database.internal.com \
  --from-literal=port=5432 \
  --namespace=production \
  --dry-run=client -o yaml | \
  kubeseal --format yaml > database-sealed-secret.yaml
```

### TLS Certificates

```bash
kubectl create secret tls example-tls \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key \
  --namespace=production \
  --dry-run=client -o yaml | \
  kubeseal --format yaml > tls-sealed-secret.yaml
```

### Docker Registry Credentials

```bash
kubectl create secret docker-registry regcred \
  --docker-server=https://registry.example.com \
  --docker-username=myuser \
  --docker-password=mypassword \
  --docker-email=user@example.com \
  --namespace=production \
  --dry-run=client -o yaml | \
  kubeseal --format yaml > registry-sealed-secret.yaml
```

## Monitoring and Management

### Check Controller Status

```bash
# Verify controller is running
kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets-controller

# Check controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=sealed-secrets-controller

# Verify service is accessible
kubectl get svc -n kube-system sealed-secrets-controller
```

### List SealedSecrets

```bash
# List all SealedSecrets
kubectl get sealedsecrets -A

# Get details of a specific SealedSecret
kubectl describe sealedsecret mysecret -n default
```

### Validate Encryption

```bash
# Check if secret was properly decrypted
kubectl get secret mysecret -n default -o yaml

# Verify secret is usable
kubectl get secret mysecret -n default -o jsonpath='{.data.username}' | base64 -d
```

## Key Management

### Backup Encryption Keys

⚠️ **Critical**: Backup the master key to avoid data loss:

```bash
kubectl get secret -n kube-system sealed-secrets-key -o yaml > master-key-backup.yaml
```

Store this backup securely and separately from your Git repository.

### Key Rotation

Keys are automatically rotated every 30 days. Old keys are retained for decryption of existing secrets.

```bash
# Check current keys
kubectl get secrets -n kube-system | grep sealed-secrets-key

# Force key rotation (if needed)
kubectl delete secret sealed-secrets-key -n kube-system
kubectl delete pod -n kube-system -l app.kubernetes.io/name=sealed-secrets-controller
```

## Troubleshooting

### Common Issues

1. **SealedSecret Not Decrypting**

   ```bash
   # Check controller logs
   kubectl logs -n kube-system -l app.kubernetes.io/name=sealed-secrets-controller

   # Verify SealedSecret status
   kubectl describe sealedsecret <name> -n <namespace>
   ```

2. **Wrong Namespace Error**

   ```bash
   # Ensure SealedSecret and target Secret have same namespace
   kubectl get sealedsecret <name> -n <namespace> -o yaml
   ```

3. **Certificate Issues**

   ```bash
   # Re-fetch certificate
   kubeseal --fetch-cert > fresh-cert.pem

   # Test connection to controller
   kubectl port-forward -n kube-system svc/sealed-secrets-controller 8080:8080
   curl http://localhost:8080/v1/cert.pem
   ```

### Debugging Encryption

```bash
# Validate a SealedSecret without applying
kubeseal --validate < sealed-secret.yaml

# Check if controller can reach the secret
kubectl auth can-i create secrets --as=system:serviceaccount:kube-system:sealed-secrets-controller
```

### Recovery Procedures

1. **Lost Master Key**: Restore from backup

   ```bash
   kubectl apply -f master-key-backup.yaml
   kubectl delete pod -n kube-system -l app.kubernetes.io/name=sealed-secrets-controller
   ```

2. **Corrupted SealedSecret**: Re-encrypt from source

   ```bash
   # Delete corrupted SealedSecret
   kubectl delete sealedsecret <name> -n <namespace>

   # Re-create from original source
   kubeseal --format yaml < original-secret.yaml > new-sealed-secret.yaml
   kubectl apply -f new-sealed-secret.yaml
   ```

## Best Practices

1. **Version Control**: Always commit SealedSecrets to Git, never raw Secrets
2. **Backup Strategy**: Regularly backup the master encryption key
3. **Access Control**: Limit access to the `kubeseal` CLI and cluster certificates
4. **Validation**: Test SealedSecrets in development before production
5. **Monitoring**: Monitor controller health and secret decryption status
6. **Documentation**: Document which secrets exist and their purpose
7. **Rotation**: Regularly rotate underlying secret values

## Security Considerations

- **Git Safety**: SealedSecrets are safe to store in public Git repositories
- **Key Protection**: Master keys must be protected and backed up securely
- **Namespace Isolation**: Use namespace-scoped secrets by default
- **Access Logging**: Monitor who has access to the kubeseal CLI
- **Network Security**: Secure communication with sealed-secrets-controller

## Configuration Parameters

| Parameter                        | Description                  | Default          |
| -------------------------------- | ---------------------------- | ---------------- |
| `controller.create`              | Create controller deployment | `true`           |
| `keyrenewperiod`                 | Key renewal period           | `720h` (30 days) |
| `resources.limits.cpu`           | CPU resource limits          | `100m`           |
| `resources.limits.memory`        | Memory resource limits       | `128Mi`          |
| `metrics.serviceMonitor.enabled` | Enable Prometheus monitoring | `false`          |

---

**Note**: This Sealed Secrets installation is managed by FluxCD. Configuration changes should be made through Git.
