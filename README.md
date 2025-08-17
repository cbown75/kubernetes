# Kubernetes Infrastructure with FluxCD

A GitOps-based Kubernetes infrastructure configuration using FluxCD v2 for automated drift detection and reconciliation.

## Overview

This repository contains the complete Kubernetes infrastructure configuration for your cluster, managed through GitOps principles with FluxCD. The setup includes automatic drift detection that reverts any manual cluster changes back to the git-defined state.

## Repository Structure

```
├── clusters/your-cluster/          # Cluster-specific configurations
│   ├── flux-system/               # Core FluxCD system files
│   ├── apps/                      # Application deployments
│   └── infrastructure/            # Infrastructure components
│       ├── storage/               # Storage CSI drivers
│       ├── sealed-secrets/        # Secret encryption
│       ├── cert-manager/          # TLS certificate management
│       ├── traefik/              # Ingress controller
│       └── prometheus/           # Monitoring stack
├── infrastructure/                # Shared infrastructure components
│   └── storage/                  # Storage Helm charts
├── charts/                       # Custom Helm charts
└── README.md                     # This file
```

## 📚 Component Documentation

Each major system has detailed documentation:

- **[FluxCD](clusters/your-cluster/flux-system/README.md)** - GitOps controller with debugging commands
- **[Infrastructure Overview](clusters/your-cluster/infrastructure/README.md)** - All infrastructure components
- **[Storage Systems](infrastructure/storage/README.md)** - NFS & Synology CSI drivers
- **[Sealed Secrets](clusters/your-cluster/infrastructure/sealed-secrets/README.md)** - Secret encryption management
- **[Cert Manager](clusters/your-cluster/infrastructure/cert-manager/README.md)** - TLS certificate automation
- **[Traefik](clusters/your-cluster/infrastructure/traefik/README.md)** - Ingress controller
- **[Prometheus](clusters/your-cluster/infrastructure/prometheus/README.md)** - Monitoring stack

## Quick Reference

### 🔍 Cluster Status Check

```bash
# Overall FluxCD health
flux get all

# Check all infrastructure components
kubectl get kustomizations -A

# Monitor real-time changes
kubectl get kustomizations -A -w

# Check all pods across infrastructure
kubectl get pods -A | grep -E "(flux-system|cert-manager|traefik-system|monitoring|nfs-csi-driver)"
```

### 🚀 Common FluxCD Debug Commands

```bash
# Force reconciliation
flux reconcile kustomization flux-system

# Check logs
kubectl logs -n flux-system -l app=kustomize-controller

# Suspend/Resume (emergency)
flux suspend kustomization flux-system
flux resume kustomization flux-system
```

## Key Features

- **🔄 Automatic Drift Detection**: FluxCD monitors cluster state and automatically reverts manual changes
- **📜 GitOps Workflow**: All cluster changes must go through Git for traceability
- **🔐 Sealed Secrets**: Secure secret management with encrypted secrets in git
- **💾 Multi-Tier Storage**: NFS CSI driver and Synology CSI for different storage needs
- **🏗️ Infrastructure as Code**: Everything defined in version-controlled manifests
- **📊 Monitoring**: Prometheus stack for metrics and alerting
- **🌐 TLS Automation**: Automatic certificate management with Let's Encrypt

## Infrastructure Components

### Core Systems

| Component          | Namespace        | Purpose              | Status Check                                                        |
| ------------------ | ---------------- | -------------------- | ------------------------------------------------------------------- |
| **FluxCD**         | `flux-system`    | GitOps controller    | `flux get all`                                                      |
| **Sealed Secrets** | `kube-system`    | Secret encryption    | `kubectl get pods -n kube-system -l name=sealed-secrets-controller` |
| **Cert Manager**   | `cert-manager`   | TLS certificates     | `kubectl get pods -n cert-manager`                                  |
| **Traefik**        | `traefik-system` | Ingress/LoadBalancer | `kubectl get pods -n traefik-system`                                |
| **Prometheus**     | `monitoring`     | Metrics/Monitoring   | `kubectl get pods -n monitoring`                                    |

### Storage Tiers

| Storage Class                   | Type      | Access Mode | Use Case                |
| ------------------------------- | --------- | ----------- | ----------------------- |
| `synology-holocron-fast`        | iSCSI SSD | RWO         | High-performance apps   |
| `synology-iscsi-storage-delete` | iSCSI     | RWO         | Standard block storage  |
| `nfs-storage`                   | NFS       | RWX         | Shared file storage     |
| `nfs-fast`                      | NFS       | RWX         | High-performance shared |

## FluxCD Configuration

The cluster is configured with aggressive drift detection:

- **⏱️ Reconciliation Interval**: 1 minute (fast drift detection)
- **💪 Force Mode**: Enabled to recreate drifted resources
- **🏥 Health Checks**: Waits for resources to be ready before completing
- **🗑️ Garbage Collection**: Automatically removes deleted resources

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

3. **Storage issues**

   ```bash
   kubectl get pvc -A
   kubectl logs -n kube-system -l app=synology-csi-controller
   ```

4. **Certificate issues**
   ```bash
   kubectl get certificates -A
   kubectl describe clusterissuer letsencrypt-cloudflare
   ```

## Monitoring and Observability

### Prometheus Dashboard

```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Open http://localhost:9090
```

### Traefik Dashboard

```bash
kubectl port-forward -n traefik-system svc/traefik 9000:9000
# Open http://localhost:9000/dashboard/
```

### Key Metrics to Monitor

- **FluxCD reconciliation** status and duration
- **Storage usage** and performance
- **Certificate expiration** dates
- **Ingress traffic** patterns
- **Pod resource usage** across infrastructure

## Security Features

- **🔐 Encrypted Secrets**: All secrets encrypted with Sealed Secrets
- **🛡️ Network Policies**: Traffic restriction between namespaces
- **🔒 RBAC**: Least-privilege access controls
- **🌐 TLS Everywhere**: Automatic HTTPS with Let's Encrypt
- **👮 Pod Security Standards**: Restricted security contexts

## Backup and Recovery

### GitOps Backup

All configuration is version-controlled in Git repositories.

### Volume Snapshots

```bash
# Create snapshot
kubectl apply -f volume-snapshot.yaml

# List snapshots
kubectl get volumesnapshots -A
```

### Disaster Recovery

1. **Restore cluster** to working state
2. **Bootstrap FluxCD** with original repository
3. **Verify component deployment** order
4. **Check all dependencies** are satisfied

## Support and Resources

- **FluxCD Documentation**: https://fluxcd.io/docs/
- **Kubernetes Documentation**: https://kubernetes.io/docs/
- **Synology CSI**: https://github.com/SynologyOpenSource/synology-csi
- **Cert Manager**: https://cert-manager.io/docs/
- **Traefik**: https://doc.traefik.io/traefik/

## Contributing

1. Create feature branch
2. Make changes to infrastructure
3. Test in development cluster
4. Submit pull request
5. Monitor deployment after merge

---

**⚠️ Remember**: This is a GitOps-managed cluster. All changes must go through Git!

