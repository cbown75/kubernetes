# Kubernetes Infrastructure with FluxCD

A GitOps-based Kubernetes infrastructure configuration using FluxCD v2 for automated drift detection and reconciliation.

## Overview

This repository contains the complete Kubernetes infrastructure configuration for your cluster, managed through GitOps principles with FluxCD. The setup includes automatic drift detection that reverts any manual cluster changes back to the git-defined state.

## Repository Structure

```
├── clusters/korriban/                 # Cluster-specific configurations
│   ├── flux-system/                  # Core FluxCD system files
│   ├── apps/                         # Application deployments
│   │   ├── prometheus/               # Prometheus monitoring
│   │   ├── grafana/                  # Grafana dashboards
│   │   ├── loki/                     # Log aggregation
│   │   ├── alertmanager/             # Alert management
│   │   └── alloy/                    # Telemetry collection
│   └── infrastructure/               # Infrastructure components
│       ├── storage/                  # Storage CSI drivers
│       ├── sealed-secrets/           # Secret encryption
│       ├── cert-manager/             # TLS certificate management
│       ├── metallb/                  # Load balancer
│       └── istio/                    # Service mesh & ingress
├── infrastructure/                   # Shared infrastructure components
│   └── storage/                      # Storage Helm charts
├── charts/                          # Custom Helm charts
└── scripts/                         # Helper scripts for sealed secrets
```

## 📚 Component Documentation

Each major system has detailed documentation:

- **[FluxCD](clusters/korriban/flux-system/README.md)** - GitOps controller with debugging commands
- **[Infrastructure Overview](clusters/korriban/infrastructure/README.md)** - All infrastructure components
- **[Storage Systems](infrastructure/storage/README.md)** - NFS & Synology CSI drivers
- **[Sealed Secrets](clusters/korriban/infrastructure/sealed-secrets/README.md)** - Secret encryption management
- **[Cert Manager](infrastructure/cert-manager)** - TLS certificate automation
- **[MetalLB](clusters/korriban/infrastructure/metallb/README.md)** - Load balancer for bare metal
- **[Istio](clusters/korriban/infrastructure/istio/README.md)** - Service mesh and ingress controller
- **[Prometheus Stack](clusters/korriban/apps/prometheus/README.md)** - Monitoring and alerting

## 🏗️ Infrastructure Architecture

```
Internet
    │
    ▼
Router (10.10.7.1)
    │
    └── MetalLB Pool: 10.10.7.200-250
        │
        ├── 10.10.7.210: Istio Ingress (Main Entry Point)
        │   │
        │   ├── grafana.home.cwbtech.net
        │   ├── prometheus.home.cwbtech.net
        │   ├── alertmanager.home.cwbtech.net
        │   └── loki.home.cwbtech.net
        │
        └── Available: 10.10.7.200-209, 211-250
```

## 🚀 Quick Reference

### 🔍 Cluster Status Check

```bash
# Overall FluxCD health
flux get all

# Check all infrastructure components
kubectl get kustomizations -A

# Monitor real-time changes
kubectl get kustomizations -A -w

# Check all pods across infrastructure
kubectl get pods -A | grep -E "(flux-system|cert-manager|istio-system|monitoring|metallb-system)"
```

### 🌐 Service Access

All services are accessible via **Istio ingress** at `https://*.home.cwbtech.net`:

- **Grafana**: https://grafana.home.cwbtech.net
- **Prometheus**: https://prometheus.home.cwbtech.net
- **AlertManager**: https://alertmanager.home.cwbtech.net
- **Loki**: https://loki.home.cwbtech.net

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
- **📊 Complete Observability**: Prometheus, Grafana, Loki, and AlertManager stack
- **🌐 Service Mesh**: Istio for advanced traffic management, security, and observability
- **🌐 TLS Automation**: Automatic certificate management with Let's Encrypt

## Infrastructure Components

### Core Systems

| Component          | Namespace        | Purpose           | Status Check                                                        |
| ------------------ | ---------------- | ----------------- | ------------------------------------------------------------------- | --------- |
| **FluxCD**         | `flux-system`    | GitOps Controller | `flux get all`                                                      |
| **Sealed Secrets** | `kube-system`    | Secret Encryption | `kubectl get pods -n kube-system -l name=sealed-secrets-controller` |
| **Cert Manager**   | `cert-manager`   | TLS Automation    | `kubectl get pods -n cert-manager`                                  |
| **MetalLB**        | `metallb-system` | Load Balancer     | `kubectl get pods -n metallb-system`                                |
| **Istio**          | `istio-system`   | Service Mesh      | `kubectl get pods -n istio-system`                                  |
| **Storage**        | `kube-system`    | CSI Drivers       | `kubectl get pods -n kube-system                                    | grep csi` |

### Monitoring Stack

| Component        | Namespace    | Purpose            | Access URL                            |
| ---------------- | ------------ | ------------------ | ------------------------------------- |
| **Prometheus**   | `monitoring` | Metrics Collection | https://prometheus.home.cwbtech.net   |
| **Grafana**      | `monitoring` | Visualization      | https://grafana.home.cwbtech.net      |
| **AlertManager** | `monitoring` | Alert Management   | https://alertmanager.home.cwbtech.net |
| **Loki**         | `monitoring` | Log Aggregation    | https://loki.home.cwbtech.net         |

## Network Configuration

### Required DNS Records

Point these domains to **10.10.7.210** (Istio LoadBalancer IP):

```
*.home.cwbtech.net → 10.10.7.210
```

Or individual entries:

```
grafana.home.cwbtech.net → 10.10.7.210
prometheus.home.cwbtech.net → 10.10.7.210
alertmanager.home.cwbtech.net → 10.10.7.210
loki.home.cwbtech.net → 10.10.7.210
```

### Router Configuration

Required DHCP exclusions to prevent IP conflicts:

- `10.10.7.2-8`: Node IPs (static)
- `10.10.7.200-250`: MetalLB service pool

### Firewall Rules (Optional)

For external access from the internet:

- Port 80 → 10.10.7.210:80 (HTTP)
- Port 443 → 10.10.7.210:443 (HTTPS)

## GitOps Workflow

### Standard Operations

All changes must be made through Git:

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

## Security Features

- **🔐 Encrypted Secrets**: All secrets encrypted with Sealed Secrets
- **🛡️ Network Policies**: Traffic restriction between namespaces
- **🔒 RBAC**: Least-privilege access controls
- **🌐 TLS Everywhere**: Automatic HTTPS with Let's Encrypt
- **👮 Pod Security Standards**: Restricted security contexts
- **🔐 Service Mesh Security**: mTLS and security policies with Istio

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

## Troubleshooting

### Common Issues

1. **Kustomization stuck in "Ready: False"**

   ```bash
   kubectl describe kustomization <name> -n flux-system
   ```

2. **Service not accessible**

   ```bash
   # Check Istio ingress
   kubectl get virtualservice -A
   kubectl get gateway -A
   kubectl get svc -n istio-system
   ```

3. **Certificate issues**
   ```bash
   kubectl get certificates -A
   kubectl describe clusterissuer letsencrypt-cloudflare
   ```

## Support and Resources

- **FluxCD Documentation**: https://fluxcd.io/docs/
- **Kubernetes Documentation**: https://kubernetes.io/docs/
- **Istio Documentation**: https://istio.io/latest/docs/
- **Cert Manager**: https://cert-manager.io/docs/
- **MetalLB**: https://metallb.universe.tf/
- **Grafana**: https://grafana.com/docs/

## Contributing

1. Create feature branch
2. Make changes to infrastructure
3. Test in development cluster
4. Submit pull request
5. Monitor deployment after merge

---

**⚠️ Remember**: This is a GitOps-managed cluster. All changes must go through Git!
