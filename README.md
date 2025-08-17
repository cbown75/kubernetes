# Kubernetes Infrastructure with FluxCD

A GitOps-based Kubernetes infrastructure configuration using FluxCD v2 for automated drift detection and reconciliation.

## Overview

This repository contains the complete Kubernetes infrastructure configuration for the `korriban` cluster, managed through GitOps principles with FluxCD. The setup includes automatic drift detection that reverts any manual cluster changes back to the git-defined state.

## Repository Structure

```
├── clusters/korriban/           # Cluster-specific configurations
│   ├── flux-system/            # Core FluxCD system files
│   ├── apps/                   # Application deployments
│   └── infrastructure/         # Infrastructure components
├── infrastructure/             # Shared infrastructure components
│   └── storage/               # Storage solutions
├── charts/                    # Custom Helm charts
└── README.md                  # This file
```

## Key Features

- **Automatic Drift Detection**: FluxCD monitors cluster state and automatically reverts manual changes
- **GitOps Workflow**: All cluster changes must go through Git for traceability
- **Sealed Secrets**: Secure secret management with encrypted secrets in git
- **Storage Solutions**: NFS CSI driver and Synology CSI support
- **Infrastructure as Code**: Everything defined in version-controlled manifests

## FluxCD Configuration

The cluster is configured with aggressive drift detection:

- **Reconciliation Interval**: 1 minute (fast drift detection)
- **Force Mode**: Enabled to recreate drifted resources
- **Health Checks**: Waits for resources to be ready before completing
- **Garbage Collection**: Automatically removes deleted resources

### Drift Detection Behavior

FluxCD will automatically:

1. Detect manual changes to cluster resources every minute
2. Force recreation of any modified resources to match git state
3. Remove resources that were deleted from git
4. Ensure all resources are healthy before marking reconciliation complete

## Quick Start

### Prerequisites

- Kubernetes cluster v1.20+
- kubectl configured for cluster access
- FluxCD CLI (optional but recommended)

### Monitoring FluxCD

```bash
# Check FluxCD system status
kubectl get kustomizations -A

# Monitor reconciliation in real-time
kubectl get kustomizations -A -w

# Check specific kustomization details
kubectl describe kustomization flux-system -n flux-system

# View FluxCD logs
kubectl logs -n flux-system -l app=kustomize-controller
```

## Components

### Core Infrastructure

- **FluxCD v2**: GitOps operator with drift detection
- **Sealed Secrets**: Encrypted secret management
- **Cert Manager**: Automatic TLS certificate management
- **Traefik**: Ingress controller and load balancer

### Storage

- **NFS CSI Driver**: Network File System storage
- **Synology CSI**: Synology NAS integration

### Applications

Application deployments are managed in the `clusters/korriban/apps/` directory and automatically synchronized with the cluster.

## Making Changes

⚠️ **Important**: Do NOT make manual changes to the cluster. All changes must be made through Git.

### Standard Workflow

1. **Make changes** in git (edit YAML files)
2. **Commit and push** to the main branch
3. **FluxCD automatically applies** changes within 1 minute
4. **Monitor status** with `kubectl get kustomizations -A`

### Emergency Procedures

If you need to make emergency changes:

1. **Disable FluxCD temporarily**:

   ```bash
   kubectl scale deployment -n flux-system kustomize-controller --replicas=0
   ```

2. **Make manual changes** to the cluster

3. **Update git** to match your manual changes

4. **Re-enable FluxCD**:
   ```bash
   kubectl scale deployment -n flux-system kustomize-controller --replicas=1
   ```

## Troubleshooting

### Common Issues

1. **Kustomization stuck in "Ready: False"**

   ```bash
   kubectl describe kustomization <name> -n flux-system
   ```

2. **Resources being constantly recreated**
   - Check if you have competing controllers modifying the same resources
   - Review resource definitions for conflicts with autoscalers

3. **FluxCD not detecting changes**
   ```bash
   # Force reconciliation
   kubectl annotate kustomization flux-system -n flux-system reconcile.fluxcd.io/requestedAt="$(date +%s)"
   ```

### Useful Commands

```bash
# Suspend reconciliation for maintenance
kubectl patch kustomization flux-system -n flux-system --type='merge' -p='{"spec":{"suspend":true}}'

# Resume reconciliation
kubectl patch kustomization flux-system -n flux-system --type='merge' -p='{"spec":{"suspend":false}}'

# Check git repository status
kubectl get gitrepositories -A

# View reconciliation events
kubectl get events -n flux-system --sort-by='.lastTimestamp'
```

## Security Considerations

- All secrets are encrypted using Sealed Secrets before being stored in git
- RBAC is properly configured for FluxCD service accounts
- Network policies should be implemented for production environments
- Regular security scanning is recommended for container images

## Contributing

1. Create a feature branch from `main`
2. Make your changes and test locally if possible
3. Submit a pull request with a clear description
4. Monitor the deployment after merge

## Documentation

- [FluxCD Official Documentation](https://fluxcd.io/docs/)
- [Sealed Secrets Documentation](https://sealed-secrets.netlify.app/)
- [Component-specific READMEs](./clusters/korriban/) in subdirectories

## Support

For issues related to:

- **FluxCD**: Check logs and kustomization status
- **Storage**: Review CSI driver documentation
- **Applications**: Check application-specific logs and configurations

---

**Note**: This cluster uses aggressive drift detection. Any manual changes will be automatically reverted within 1 minute.

