# FluxCD v2 - GitOps Controller

## Overview

FluxCD v2 is the GitOps operator managing the entire `korriban` cluster infrastructure. It provides continuous delivery and automatic drift detection, ensuring the cluster state always matches what's defined in Git.

## Architecture

```
GitRepository → Kustomizations → Kubernetes Resources
     ↓              ↓                    ↓
  Git Commits → Auto Sync → Resource Updates
     ↓              ↓                    ↓
  1 Minute    Drift Detection    Force Recreation
```

## Key Features

- **Drift Detection**: Monitors cluster state every minute
- **Force Reconciliation**: Automatically recreates drifted resources
- **Multi-Source**: Manages both Kustomizations and Helm releases
- **Health Checks**: Waits for resources to be ready
- **Garbage Collection**: Removes deleted resources

## Configuration

### Current Setup

- **Reconciliation Interval**: 1 minute
- **Timeout**: 10 minutes
- **Force Mode**: Enabled
- **Prune**: Enabled (removes deleted resources)
- **Wait**: Enabled (waits for health checks)

### Managed Resources

- **Source Controllers**: Git repository monitoring
- **Kustomize Controllers**: YAML manifests and Kustomizations
- **Helm Controllers**: Helm chart deployments
- **Notification Controllers**: Alerts and webhooks

## Common FluxCD Debugging Commands

### Cluster Status Overview

```bash
# Quick cluster health check
flux get all

# Check all kustomizations across namespaces
kubectl get kustomizations -A

# Monitor real-time changes
kubectl get kustomizations -A -w

# Check all GitRepositories
kubectl get gitrepositories -A

# Check all HelmReleases
kubectl get helmreleases -A
```

### Detailed Resource Inspection

```bash
# Examine specific kustomization
kubectl describe kustomization flux-system -n flux-system

# Check GitRepository status
kubectl describe gitrepository flux-system -n flux-system

# View HelmRelease details
kubectl describe helmrelease <name> -n <namespace>

# Check source status
flux get sources git --all-namespaces
```

### Log Analysis

```bash
# View all FluxCD logs
kubectl logs -n flux-system -l app.kubernetes.io/part-of=flux

# Source controller logs (Git operations)
kubectl logs -n flux-system -l app=source-controller

# Kustomize controller logs (YAML manifests)
kubectl logs -n flux-system -l app=kustomize-controller

# Helm controller logs (Helm releases)
kubectl logs -n flux-system -l app=helm-controller

# Follow logs in real-time
kubectl logs -n flux-system -l app=kustomize-controller -f
```

### Force Reconciliation

```bash
# Force reconcile all resources
flux reconcile kustomization flux-system

# Force reconcile specific kustomization
flux reconcile kustomization <name> --namespace <namespace>

# Force reconcile GitRepository
flux reconcile source git flux-system

# Force reconcile HelmRelease
flux reconcile helmrelease <name> --namespace <namespace>
```

### Suspension and Recovery

```bash
# Suspend reconciliation (emergency stop)
flux suspend kustomization flux-system

# Resume reconciliation
flux resume kustomization flux-system

# Suspend specific HelmRelease
flux suspend helmrelease <name> --namespace <namespace>

# Resume specific HelmRelease
flux resume helmrelease <name> --namespace <namespace>
```

### Git Source Debugging

```bash
# Check Git source status
flux get sources git

# View Git source events
kubectl describe gitrepository flux-system -n flux-system

# Check if Git is accessible
kubectl exec -n flux-system deployment/source-controller -- \
  git ls-remote https://github.com/your-org/kubernetes-infrastructure.git

# Verify Git credentials (if using private repo)
kubectl get secret -n flux-system
```

### Troubleshooting Failed Deployments

```bash
# Check for failed resources
kubectl get kustomizations -A | grep -v True

# Examine failure details
kubectl describe kustomization <failing-kustomization> -n <namespace>

# Check events for issues
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Validate YAML before applying
flux diff kustomization <name> --path <path>
```

### Performance and Resource Monitoring

```bash
# Check FluxCD resource usage
kubectl top pods -n flux-system

# Monitor reconciliation frequency
kubectl get kustomizations -A -o custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace,READY:.status.conditions[0].status,LAST-APPLIED:.status.lastAppliedRevision,AGE:.metadata.creationTimestamp

# Check reconciliation intervals
kubectl get kustomizations -A -o yaml | grep -A 5 -B 5 interval
```

### Bootstrap and Recovery

```bash
# Bootstrap FluxCD (initial setup)
flux bootstrap github \
  --owner=<github-user> \
  --repository=<repo-name> \
  --branch=main \
  --path=clusters/korriban

# Check bootstrap status
flux check

# Reinstall FluxCD components
flux install --export > flux-system.yaml
kubectl apply -f flux-system.yaml

# Uninstall FluxCD (danger!)
flux uninstall --silent
```

### Dependency Troubleshooting

```bash
# Check resource dependencies
kubectl get kustomizations -A -o custom-columns=NAME:.metadata.name,DEPENDS-ON:.spec.dependsOn[*].name

# View dependency chain
flux tree kustomization flux-system

# Check health assessment
kubectl get kustomizations -A -o custom-columns=NAME:.metadata.name,HEALTH:.status.conditions[?(@.type==\"Healthy\")].status
```

## Common Issues and Solutions

### 1. Kustomization Stuck in "Ready: False"

**Symptoms**: Kustomization shows False/Unknown status

**Diagnosis**:

```bash
kubectl describe kustomization <name> -n <namespace>
kubectl logs -n flux-system -l app=kustomize-controller
```

**Solutions**:

- Check for YAML syntax errors
- Verify resource dependencies
- Check RBAC permissions
- Force reconciliation

### 2. Git Repository Not Syncing

**Symptoms**: LastUpdateTime not advancing

**Diagnosis**:

```bash
kubectl describe gitrepository <name> -n <namespace>
kubectl logs -n flux-system -l app=source-controller
```

**Solutions**:

- Verify Git repository access
- Check network connectivity
- Validate Git credentials
- Check branch/tag references

### 3. Resources Being Constantly Recreated

**Symptoms**: Resources showing frequent updates

**Diagnosis**:

```bash
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
kubectl describe <resource-type> <resource-name> -n <namespace>
```

**Solutions**:

- Check for competing controllers
- Review resource definitions for conflicts
- Verify autoscaler configurations
- Check for manual modifications

### 4. Helm Release Failures

**Symptoms**: HelmRelease in failed state

**Diagnosis**:

```bash
kubectl describe helmrelease <name> -n <namespace>
kubectl logs -n flux-system -l app=helm-controller
```

**Solutions**:

- Check Helm chart validity
- Verify values configuration
- Check resource limits
- Review dependency order

### 5. Permission Denied Errors

**Symptoms**: RBAC or permission errors in logs

**Diagnosis**:

```bash
kubectl auth can-i <verb> <resource> --as=system:serviceaccount:<namespace>:<serviceaccount>
kubectl describe clusterrolebinding flux-system
```

**Solutions**:

- Review RBAC configurations
- Check service account permissions
- Verify cluster-admin access
- Update FluxCD RBAC

## Emergency Procedures

### Disable FluxCD (Emergency Stop)

```bash
# Scale down all controllers
kubectl scale deployment -n flux-system source-controller --replicas=0
kubectl scale deployment -n flux-system kustomize-controller --replicas=0
kubectl scale deployment -n flux-system helm-controller --replicas=0

# Verify controllers are stopped
kubectl get deployments -n flux-system
```

### Re-enable FluxCD

```bash
# Scale up all controllers
kubectl scale deployment -n flux-system source-controller --replicas=1
kubectl scale deployment -n flux-system kustomize-controller --replicas=1
kubectl scale deployment -n flux-system helm-controller --replicas=1

# Verify controllers are running
kubectl get pods -n flux-system
```

### Reset FluxCD State

```bash
# Delete and recreate kustomization
kubectl delete kustomization flux-system -n flux-system
flux reconcile source git flux-system

# Force recreation of all resources
kubectl annotate kustomization flux-system -n flux-system reconcile.fluxcd.io/requestedAt="$(date +%s)"
```

## Monitoring and Alerting

### Health Checks

```bash
# Overall FluxCD health
flux check

# Check specific components
flux check --components source-controller,kustomize-controller,helm-controller

# Verify connectivity
flux check --pre
```

### Metrics and Observability

FluxCD exposes Prometheus metrics on port 8080:

```bash
# Check metrics endpoint
kubectl port-forward -n flux-system svc/source-controller 8080:80
curl http://localhost:8080/metrics

# Key metrics to monitor:
# - gotk_reconcile_duration_seconds
# - gotk_reconcile_condition_info
# - controller_runtime_reconcile_total
```

## Best Practices

1. **Always commit changes to Git first** - Never make manual cluster changes
2. **Monitor reconciliation status** - Use `kubectl get kustomizations -A` regularly
3. **Test in staging** - Validate changes before applying to production
4. **Use proper Git workflow** - Feature branches and pull requests
5. **Monitor logs** - Set up log aggregation for FluxCD controllers
6. **Set up alerts** - Configure monitoring for failed reconciliations
7. **Regular backups** - Backup FluxCD configuration and Git repositories
8. **Document changes** - Maintain clear commit messages and documentation

## Security Considerations

- **Least Privilege**: FluxCD runs with cluster-admin by default - consider restricting
- **Secret Management**: Use Sealed Secrets or external secret operators
- **Git Security**: Use SSH keys or tokens for Git access
- **Network Policies**: Implement network policies for FluxCD namespace
- **Image Security**: Keep FluxCD images updated
- **Audit Logs**: Monitor FluxCD activities through Kubernetes audit logs

## Resources

- **Official Documentation**: https://fluxcd.io/docs/
- **GitHub Repository**: https://github.com/fluxcd/flux2
- **Community**: https://fluxcd.io/community/
- **Troubleshooting Guide**: https://fluxcd.io/docs/cheatsheets/troubleshooting/
