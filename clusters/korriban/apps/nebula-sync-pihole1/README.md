# Nebula Sync - PiHole Synchronization

A Kubernetes Helm chart to deploy Nebula Sync for synchronizing PiHole configurations across multiple instances.

## 🚀 Quick Start

### 1. Repository Structure

Add the chart to your repository following this structure:

```
cbown75/kubernetes/
├── apps/
│   └── nebula-sync/
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── templates/
│       │   ├── deployment.yaml
│       │   ├── sealed-secret.yaml
│       │   ├── configmap.yaml
│       │   ├── serviceaccount.yaml
│       │   ├── networkpolicy.yaml
│       │   └── _helpers.tpl
│       ├── helmrelease.yaml
│       ├── kustomization.yaml
│       └── README.md
```

### 2. Generate Sealed Secrets

**CRITICAL**: You must encrypt your PiHole passwords before deployment:

```bash
# Install kubeseal if not already installed
brew install kubeseal  # macOS
# or download from https://github.com/bitnami-labs/sealed-secrets/releases

# Encrypt your PiHole password (replace with your actual password)
echo -n "Husk3r?!94" | kubeseal --raw --name nebula-sync-secrets --namespace default

# You'll get output like: AgBy3i4OJSWK+PfU7H5... (this is your encrypted value)
```

### 3. Update Configuration

Edit `apps/nebula-sync/helmrelease.yaml` and replace the empty sealed secret values:

```yaml
sealedSecrets:
  enabled: true
  secrets:
    nebula-sync-secrets:
      # Replace these empty strings with your encrypted values:
      primary-password: "AgBy3i4OJSWK+PfU7H5..." # <-- Your encrypted primary password
      replica-password-1: "AgBy3i4OJSWK+PfU7H5..." # <-- Your encrypted replica password
      replica-password-2: "AgBy3i4OJSWK+PfU7H5..." # <-- Your encrypted replica password
      replica-password-3: "AgBy3i4OJSWK+PfU7H5..." # <-- Your encrypted replica password
```

### 4. Deploy via GitOps

```bash
# Commit and push to your repository
git add apps/nebula-sync/
git commit -m "Add nebula-sync application"
git push origin main

# FluxCD will automatically detect and deploy the application
```

### 5. Verify Deployment

```bash
# Check FluxCD status
flux get helmreleases

# Check pod status
kubectl get pods -l app.kubernetes.io/name=nebula-sync

# Check logs
kubectl logs -l app.kubernetes.io/name=nebula-sync -f
```

## 📋 Configuration

### Sync Schedule

The application runs on a cron schedule. Default is every hour at 5 minutes past (`05 * * * *`).

### Sync Features

By default, the following are synchronized:

- ✅ DNS configuration
- ✅ DHCP configuration
- ✅ NTP configuration
- ✅ Resolver configuration
- ✅ Database configuration
- ✅ All Gravity features (ad lists, domains, clients, groups)
- ❌ Miscellaneous configuration (disabled)
- ❌ Debug mode (disabled)

### PiHole Instances

- **Primary**: `pihole1.home.cwbtech.net` (source of truth)
- **Replicas**:
  - `pihole2.home.cwbtech.net`
  - `pihole7.home.cwbtech.net`
  - `pihole8.home.cwbtech.net`

## 🔧 Customization

### Changing Sync Schedule

Edit the `cron` value in `helmrelease.yaml`:

```yaml
nebulaSync:
  config:
    cron: "*/30 * * * *"  # Every 30 minutes
    # or
    cron: "0 */6 * * *"   # Every 6 hours
```

### Modifying Sync Features

```yaml
nebulaSync:
  dhcp:
    enabled: false # Disable DHCP sync
  debug:
    enabled: true # Enable debug logging
```

### Resource Limits

```yaml
resources:
  limits:
    memory: "512Mi" # Increase if needed
    cpu: "500m"
  requests:
    memory: "256Mi"
    cpu: "200m"
```

## 🚨 Security Notes

1. **Passwords are encrypted** using Sealed Secrets - they cannot be decrypted without access to your cluster
2. **Network policies** restrict egress to only DNS and HTTP traffic
3. **Security contexts** run as non-root with read-only filesystem
4. **No ingress exposure** - this is a background job only

## 🔍 Troubleshooting

### Check Sync Status

```bash
# View recent logs
kubectl logs -l app.kubernetes.io/name=nebula-sync --tail=50

# Follow logs in real-time
kubectl logs -l app.kubernetes.io/name=nebula-sync -f
```

### Common Issues

**Pod not starting:**

```bash
# Check sealed secret creation
kubectl get sealedsecrets
kubectl get secrets | grep nebula-sync

# Verify sealed-secrets controller
kubectl get pods -n kube-system | grep sealed-secrets
```

**Sync failures:**

- Verify PiHole instances are accessible from cluster
- Check if passwords are correct
- Review network policies if using custom networking

**Certificate/Connection errors:**

- Ensure PiHole instances use HTTP (not HTTPS) or add proper TLS configuration

### Force Manual Sync

```bash
# Restart the deployment to trigger immediate sync
kubectl rollout restart deployment/nebula-sync
```

## 📊 Monitoring

The application includes basic monitoring capabilities:

```bash
# Check deployment status
kubectl get deployment nebula-sync

# View events
kubectl get events --sort-by='.lastTimestamp' | grep nebula-sync

# Resource usage
kubectl top pod -l app.kubernetes.io/name=nebula-sync
```

## 🔄 Updates

To update the application:

1. Modify values in `helmrelease.yaml`
2. Commit and push changes
3. FluxCD will automatically reconcile within 5 minutes

```bash
# Force immediate reconciliation
flux reconcile helmrelease nebula-sync
```

## 🗑️ Uninstallation

```bash
# Remove from repository
git rm -r apps/nebula-sync/
git commit -m "Remove nebula-sync application"
git push origin main

# Or manually delete
flux delete helmrelease nebula-sync
kubectl delete namespace default # Only if you want to remove everything
```

---

This chart provides a production-ready deployment of Nebula Sync that follows GitOps best practices with proper security hardening and secret management.
