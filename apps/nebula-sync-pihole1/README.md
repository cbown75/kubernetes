# Nebula Sync PiHole1 - Kubernetes Deployment

This deployment syncs PiHole configurations from pihole1 (primary) to multiple replica instances using nebula-sync.

## Overview

**Purpose**: Automatically synchronize PiHole settings, blocklists, and configurations across multiple PiHole instances.

**Primary Instance**: pihole1.home.cwbtech.net  
**Replica Instances**: pihole2, pihole7, pihole8  
**Sync Schedule**: Every 5 minutes  
**Namespace**: pihole

## Directory Structure

```
clusters/korriban/apps/
├── nebula-sync-pihole1/      # This deployment (pihole1 as primary)
│   ├── namespace.yaml
│   ├── sealed-secret.yaml
│   ├── deployment.yaml
│   └── kustomization.yaml
├── nebula-sync-pihole2/      # Future: pihole2 as primary
└── nebula-sync-pihole3/      # Future: pihole3 as primary
```

## Prerequisites

- Kubernetes cluster with FluxCD configured
- Sealed Secrets controller installed in kube-system namespace
- `kubeseal` CLI tool installed locally
- Network connectivity from cluster to all PiHole instances

## Initial Deployment

### Step 1: Generate Sealed Secret

Create a script to generate the sealed secret:

```bash
#!/bin/bash
# generate-sealed-secret.sh

# Create temporary secret (DO NOT commit this)
cat <<EOF > /tmp/nebula-sync-pihole1-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: nebula-sync-pihole1-secrets
  namespace: pihole
type: Opaque
stringData:
  primary-password: "<YOUR_PASSWORD_HERE>"
  replica-password-1: "<YOUR_PASSWORD_HERE>"
  replica-password-2: "<YOUR_PASSWORD_HERE>"
  replica-password-3: "<YOUR_PASSWORD_HERE>"
EOF

# Seal the secret
kubeseal \
  --controller-name=sealed-secrets \
  --controller-namespace=kube-system \
  --format=yaml \
  < /tmp/nebula-sync-pihole1-secret.yaml \
  > clusters/korriban/apps/nebula-sync-pihole1/sealed-secret.yaml

# Clean up
rm /tmp/nebula-sync-pihole1-secret.yaml
```

### Step 2: Create Deployment Files

Create the following files in `clusters/korriban/apps/nebula-sync-pihole1/`:

1. **namespace.yaml** - Creates the pihole namespace
2. **deployment.yaml** - Main deployment configuration
3. **kustomization.yaml** - Kustomize configuration
4. **sealed-secret.yaml** - Generated from Step 1

### Step 3: Deploy via GitOps

```bash
git add clusters/korriban/apps/nebula-sync-pihole1/
git commit -m "Add nebula-sync for pihole1"
git push
```

## Verification

### Check Deployment Status

```bash
# Check if namespace was created
kubectl get namespace pihole

# Check deployment
kubectl get deployment -n pihole nebula-sync-pihole1

# Check pods
kubectl get pods -n pihole -l app=nebula-sync-pihole1

# View logs
kubectl logs -n pihole -l app=nebula-sync-pihole1 --tail=50

# Follow logs in real-time
kubectl logs -n pihole -l app=nebula-sync-pihole1 -f
```

### Verify Sync Operation

Look for these log entries:

- "Starting nebula-sync..."
- "Schedule: Every 5 minutes"
- Sync operation results

## Configuration

### Sync Settings

The deployment is configured to sync:

- ✅ DNS settings
- ✅ DHCP configuration
- ✅ NTP settings
- ✅ Resolver configuration
- ✅ Database
- ✅ All Gravity features (blocklists, groups, clients)
- ❌ Miscellaneous settings (disabled)

### Resource Limits

```yaml
requests:
  cpu: 50m
  memory: 64Mi
limits:
  cpu: 200m
  memory: 256Mi
```

## Troubleshooting

### Pod Not Starting

```bash
# Check sealed secret
kubectl get sealedsecrets -n pihole
kubectl get secrets -n pihole

# Check pod events
kubectl describe pod -n pihole -l app=nebula-sync-pihole1

# Check deployment events
kubectl describe deployment -n pihole nebula-sync-pihole1
```

### Authentication Failures

1. Verify PiHole instances are accessible from the cluster
2. Confirm passwords are correct in sealed secret
3. Check PiHole logs for authentication errors
4. Ensure PiHole API is enabled on all instances

### Sync Not Running

```bash
# Check cron schedule in logs
kubectl logs -n pihole -l app=nebula-sync-pihole1 | grep -i cron

# Restart deployment to trigger immediate sync
kubectl rollout restart deployment -n pihole nebula-sync-pihole1
```

### DNS Resolution Issues

If pods can't resolve PiHole hostnames:

```bash
# Test DNS from a pod
kubectl run test-dns --image=busybox -it --rm -- nslookup pihole1.home.cwbtech.net
```

## Maintenance

### Update Configuration

1. Edit `deployment.yaml` with new settings
2. Commit and push changes
3. FluxCD will automatically apply within 1 minute

### Update Passwords

1. Generate new sealed secret (see Step 1)
2. Commit and push the new `sealed-secret.yaml`
3. Delete the pod to force recreation:
   ```bash
   kubectl delete pod -n pihole -l app=nebula-sync-pihole1
   ```

### View Current Configuration

```bash
# View deployment
kubectl get deployment -n pihole nebula-sync-pihole1 -o yaml

# View environment variables
kubectl exec -n pihole deployment/nebula-sync-pihole1 -- env | grep SYNC
```

## Creating Additional Instances

To sync from pihole2, pihole3, etc. as primary:

1. **Copy the directory**:

   ```bash
   cp -r clusters/korriban/apps/nebula-sync-pihole1 \
         clusters/korriban/apps/nebula-sync-pihole2
   ```

2. **Update all references** from `pihole1` to `pihole2`:
   - In `deployment.yaml`: names, labels, secret names
   - In `kustomization.yaml`: labels
   - In sealed secret: regenerate with appropriate passwords

3. **Modify URLs** in `deployment.yaml`:
   - Change PRIMARY URL to pihole2
   - Update REPLICAS URLs accordingly

4. **Generate new sealed secret** for the instance

5. **Commit and deploy**

## Removal

To completely remove the deployment:

```bash
# Via GitOps (recommended)
git rm -r clusters/korriban/apps/nebula-sync-pihole1/
git commit -m "Remove nebula-sync-pihole1"
git push

# Or manually
kubectl delete deployment -n pihole nebula-sync-pihole1
kubectl delete secret -n pihole nebula-sync-pihole1-secrets
```

## Security Notes

- Passwords are encrypted using Sealed Secrets
- Secrets are namespace-scoped to the pihole namespace
- Pod runs with minimal resource limits
- No ingress exposure - internal sync only

## References

- [Nebula Sync GitHub](https://github.com/lovelaze/nebula-sync)
- [Sealed Secrets Documentation](https://sealed-secrets.netlify.app/)
- [FluxCD Documentation](https://fluxcd.io/)
