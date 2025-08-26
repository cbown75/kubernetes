# Infrastructure Components

This directory contains all the core infrastructure components for the Kubernetes cluster, deployed and managed via FluxCD GitOps.

## Overview

The infrastructure is organized in dependency order, with each component building upon the previous ones. All components are deployed automatically by FluxCD when changes are committed to this repository.

## Component Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│    Storage      │    │ Sealed Secrets  │    │  Cert Manager   │
│   (NFS/CSI)     │    │  (Encryption)   │    │ (TLS Certs)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                        │                        │
         └────────────────────────┼────────────────────────┘
                                  │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│     MetalLB     │    │      Istio      │    │      Apps       │
│ (LoadBalancer)  │◄───┤ (Service Mesh)  │◄───┤  (Monitoring)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Infrastructure Components

### 1. Storage

- **Purpose**: Persistent storage for applications
- **Namespace**: `kube-system`
- **Features**:
  - NFS CSI driver for shared storage
  - Synology CSI driver for block storage
  - Multiple storage classes (fast, general, backup)
- **Status**: `kubectl get pods -n kube-system | grep csi`

### 2. Sealed Secrets

- **Purpose**: Encrypt secrets in Git repositories
- **Namespace**: `kube-system`
- **Features**:
  - Client-side encryption
  - Namespace-scoped or cluster-wide secrets
  - Automatic decryption in cluster
  - Git-safe secret storage
- **Status**: `kubectl get pods -n kube-system -l name=sealed-secrets-controller`

### 3. Cert Manager

- **Purpose**: Automatic TLS certificate management
- **Namespace**: `cert-manager`
- **Features**:
  - Let's Encrypt integration
  - Cloudflare DNS challenges
  - Automatic certificate renewal
  - Multiple issuers (staging/production)
- **Status**: `kubectl get pods -n cert-manager`

### 4. MetalLB

- **Purpose**: Load balancer implementation for bare metal clusters
- **Namespace**: `metallb-system`
- **Features**:
  - Layer 2 (ARP/NDP) mode
  - IP address pool management
  - Automatic IP assignment
  - High availability failover
- **IP Ranges**:
  - Default pool: `10.10.7.200-250` (Public services)
  - Internal pool: `10.10.7.100-150` (Internal services)
- **Status**: `kubectl get pods -n metallb-system`

### 5. Istio Service Mesh

- **Purpose**: Service mesh with ingress capabilities
- **Namespace**: `istio-system`
- **Features**:
  - Advanced traffic management
  - Security policies and mTLS
  - Observability and telemetry
  - **Ingress LoadBalancer IP**: `10.10.7.210` (via MetalLB)
- **Status**: `kubectl get pods -n istio-system`

## Network Architecture

```
Internet
    │
    ▼
Router (10.10.7.1)
    │
    ├── DHCP Range: 10.10.7.10-199 (Reserved for dynamic allocation)
    ├── Node IPs: 10.10.7.2-8 (Static assignments)
    ├── MetalLB Range: 10.10.7.200-250 (Reserved for LoadBalancer IPs)
    └── Internal Services: 10.10.7.100-150 (Optional internal pool)

Current Assignments:
- 10.10.7.210: Istio Ingress (Main Entry Point)
- 10.10.7.200-209, 211-250: Available for future services
```

## Quick Status Checks

### All Components Status

```bash
# Check all infrastructure kustomizations
kubectl get kustomizations -n flux-system

# Check all namespaces
kubectl get namespaces | grep -E "(flux-system|cert-manager|istio-system|monitoring|metallb-system|kube-system)"

# Check all pods across infrastructure namespaces
kubectl get pods -A | grep -E "(flux-system|cert-manager|istio-system|metallb-system|sealed-secrets|csi)"
```

### Per-Component Health Checks

#### FluxCD

```bash
# FluxCD status
flux get all
kubectl get pods -n flux-system
```

#### Sealed Secrets

```bash
# Sealed Secrets controller
kubectl get pods -n kube-system -l name=sealed-secrets-controller
kubectl logs -n kube-system -l name=sealed-secrets-controller
```

#### Cert Manager

```bash
# Cert Manager pods
kubectl get pods -n cert-manager
kubectl get clusterissuers
kubectl get certificates -A
```

#### MetalLB

```bash
# MetalLB status
kubectl get pods -n metallb-system
kubectl get ipaddresspool -n metallb-system
kubectl get svc -A | grep LoadBalancer
```

#### Istio

```bash
# Istio status
kubectl get pods -n istio-system
kubectl get svc -n istio-system
kubectl get virtualservice -A
kubectl get gateway -A
# Should show EXTERNAL-IP as 10.10.7.210
```

#### Storage

```bash
# Storage drivers
kubectl get pods -n kube-system | grep csi
kubectl get storageclasses
```

### Monitoring Stack

```bash
# Monitoring stack
kubectl get pods -n monitoring
kubectl get pvc -n monitoring
kubectl get virtualservice -n monitoring
```

## Common Troubleshooting

### Dependency Issues

If components fail to start, check dependency order:

```bash
# Check if required components are ready
kubectl get kustomizations -n flux-system -o custom-columns=NAME:.metadata.name,READY:.status.conditions[0].status,MESSAGE:.status.conditions[0].message

# Force reconciliation in dependency order
flux reconcile kustomization flux-system --with-source
```

### LoadBalancer IP Issues

```bash
# Check if service has external IP
kubectl get svc -n istio-system istio-ingress

# If stuck in Pending, check MetalLB
kubectl logs -n metallb-system deployment/metallb-controller
kubectl describe ipaddresspool -n metallb-system
```

### Storage Issues

```bash
# Check storage classes
kubectl get sc

# Check persistent volumes
kubectl get pv

# Test storage with a simple pod
kubectl run storage-test --image=busybox --rm -it --restart=Never -- sh
```

### Certificate Issues

```bash
# Check certificate status
kubectl get certificates -A
kubectl describe certificate <cert-name> -n <namespace>

# Check ClusterIssuer status
kubectl get clusterissuers
kubectl describe clusterissuer letsencrypt-cloudflare
```

### Ingress Issues

```bash
# Check Istio ingress
kubectl get virtualservice -A
kubectl describe virtualservice <route-name> -n <namespace>

# Test connectivity to LoadBalancer IP
curl -v http://10.10.7.210
curl -v https://10.10.7.210

# Check Istio ingress logs
kubectl logs -n istio-system -l app=istio-proxy
kubectl logs -n istio-system -l app=istiod
```

## Configuration Management

### GitOps Workflow

All infrastructure changes must go through Git:

1. **Make changes** in `clusters/korriban/infrastructure/`
2. **Commit and push** to repository
3. **FluxCD reconciles** automatically (or force with `flux reconcile`)
4. **Verify deployment** with status checks

### Adding New Infrastructure

1. Create directory under `infrastructure/`
2. Add `release.yaml` with Namespace, HelmRepository, and HelmRelease
3. Add `config.yaml` for additional resources if needed
4. Create `kustomization.yaml` to bundle resources
5. Update main `infrastructure/kustomization.yaml` to include new component
6. Consider dependencies and add to HelmRelease `dependsOn` if needed

## Network Requirements

### Router Configuration

Required DHCP exclusions to prevent IP conflicts:

- `10.10.7.2-8`: Node IPs (static)
- `10.10.7.100-150`: Internal service pool (MetalLB)
- `10.10.7.200-250`: Default service pool (MetalLB)

### DNS Configuration

Point these domains to `10.10.7.210` (Istio LoadBalancer IP):

- `*.home.cwbtech.net` (wildcard)
- Or individual entries:
  - `prometheus.home.cwbtech.net`
  - `grafana.home.cwbtech.net`
  - `alertmanager.home.cwbtech.net`
  - `loki.home.cwbtech.net`

### Firewall Rules

For external access, forward ports to `10.10.7.210`:

- Port 80 → 10.10.7.210:80 (HTTP)
- Port 443 → 10.10.7.210:443 (HTTPS)

## Monitoring and Maintenance

### Resource Usage

```bash
# Check resource consumption
kubectl top nodes
kubectl top pods -A | grep -E "(metallb|istio|prometheus|grafana)"
```

### Update Management

```bash
# Check for updates
flux get helmreleases -A

# Update a component (edit version in release.yaml, then)
git add infrastructure/<component>/release.yaml
git commit -m "Update <component> to version X.Y.Z"
git push
```

### Backup Considerations

Critical components to backup:

- Sealed Secrets keys (automatic via Git)
- Prometheus data (PVC)
- Grafana dashboards (ConfigMaps)
- Cert Manager certificates (Secrets)

## Security Considerations

1. **Network Policies**: Implemented for namespace isolation
2. **TLS Everywhere**: Automatic HTTPS with cert-manager
3. **Secret Encryption**: All secrets encrypted with Sealed Secrets
4. **RBAC**: Proper role-based access control
5. **Resource Limits**: All components have defined resource limits
6. **Security Contexts**: Non-root users, read-only filesystems where possible
7. **Service Mesh Security**: mTLS and security policies with Istio

## Performance Tuning

- **MetalLB**: Minimal overhead, scales with number of services
- **Istio**: Optimized for high throughput and low latency
- **Prometheus**: 15-day retention, 50GB storage
- **Grafana**: Configured for efficient query caching

## References

- [FluxCD Documentation](https://fluxcd.io/docs/)
- [MetalLB Documentation](https://metallb.universe.tf/)
- [Istio Documentation](https://istio.io/latest/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Cert Manager Documentation](https://cert-manager.io/docs/)
- [Sealed Secrets Documentation](https://sealed-secrets.netlify.app/)
