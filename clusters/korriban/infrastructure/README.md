# Infrastructure Components

## Overview

This directory contains the core infrastructure components for the `korriban` cluster, deployed and managed through FluxCD. All components are designed to work together to provide a complete Kubernetes platform.

## Component Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   FluxCD        │    │  Sealed Secrets  │    │  Cert Manager   │
│   (GitOps)      │────│  (Secret Mgmt)   │────│  (TLS Certs)    │
└─────────────────┘    └──────────────────┘    └─────────────────┘
          │                        │                        │
          ▼                        ▼                        ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   MetalLB       │    │     Traefik      │    │    Storage      │
│   (Load LB)     │────│    (Ingress)     │────│  (CSI Drivers)  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
          │                        │                        │
          ▼                        ▼                        ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Prometheus    │    │     Grafana      │    │   Applications  │
│   (Monitoring)  │────│  (Visualization) │────│   (Workloads)   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Deployment Order

The infrastructure components are deployed in dependency order:

1. **Storage** - NFS & Synology CSI drivers
2. **Sealed Secrets** - Secret encryption and management
3. **Cert Manager** - TLS certificate automation
4. **MetalLB** - Load balancer for bare metal
5. **Traefik** - Ingress controller and routing
6. **Prometheus** - Monitoring and metrics collection
7. **Grafana** - Metrics visualization

## Components

### 1. Storage Systems

#### NFS CSI Driver

- **Purpose**: Network File System storage for shared volumes
- **Namespace**: `nfs-csi-driver`
- **Features**:
  - ReadWriteMany volumes
  - Dynamic provisioning
  - Multiple access modes

#### Synology CSI Driver

- **Purpose**: Synology NAS integration for high-performance storage
- **Namespace**: `kube-system`
- **Features**:
  - iSCSI block storage
  - Volume expansion
  - Snapshots support
  - High performance SSDs

### 2. Sealed Secrets

- **Purpose**: Encrypt secrets in Git repositories
- **Namespace**: `kube-system`
- **Features**:
  - Client-side encryption
  - Namespace-scoped or cluster-wide secrets
  - Automatic decryption in cluster
  - Git-safe secret storage

### 3. Cert Manager

- **Purpose**: Automatic TLS certificate management
- **Namespace**: `cert-manager`
- **Features**:
  - Let's Encrypt integration
  - Cloudflare DNS challenges
  - Automatic certificate renewal
  - Multiple issuers (staging/production)

### 4. MetalLB (NEW)

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

### 5. Traefik Ingress Controller

- **Purpose**: HTTP/HTTPS ingress and load balancing
- **Namespace**: `traefik-system`
- **Features**:
  - Automatic service discovery
  - TLS termination
  - Dashboard and API
  - Metrics export
  - **LoadBalancer IP**: `10.10.7.200` (via MetalLB)

### 6. Prometheus Monitoring

- **Purpose**: Metrics collection and monitoring
- **Namespace**: `monitoring`
- **Features**:
  - Metrics scraping
  - Time-series database
  - Web UI with queries
  - Persistent storage
  - **Access**: https://prometheus.home.cwbtech.net

### 7. Grafana Visualization

- **Purpose**: Metrics visualization and dashboards
- **Namespace**: `monitoring`
- **Features**:
  - Custom dashboards
  - Prometheus integration
  - Alert management
  - User authentication
  - **Access**: https://grafana.home.cwbtech.net

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
- 10.10.7.200: Traefik (Main Ingress)
- 10.10.7.201-250: Available for future services
```

## Quick Status Checks

### All Components Status

```bash
# Check all infrastructure kustomizations
kubectl get kustomizations -n flux-system

# Check all namespaces
kubectl get namespaces | grep -E "(flux-system|cert-manager|traefik-system|monitoring|metallb-system|nfs-csi-driver)"

# Check all pods across infrastructure namespaces
kubectl get pods -A | grep -E "(flux-system|cert-manager|traefik-system|monitoring|metallb-system|nfs-csi-driver)"
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

#### Traefik

```bash
# Traefik status
kubectl get pods -n traefik-system
kubectl get svc -n traefik-system
kubectl get ingressroutes -A
# Should show EXTERNAL-IP from MetalLB (10.10.7.200)
```

#### Storage

```bash
# Storage drivers
kubectl get pods -n nfs-csi-driver
kubectl get pods -n kube-system | grep synology
kubectl get storageclasses
```

#### Prometheus & Grafana

```bash
# Monitoring stack
kubectl get pods -n monitoring
kubectl get pvc -n monitoring
kubectl get ingress -n monitoring
```

## Common Troubleshooting

### Dependency Issues

If components fail to start, check dependency order:

```bash
# Check if required components are ready
kubectl get kustomizations -n flux-system -o custom-columns=NAME:.metadata.name,READY:.status.conditions[0].status,MESSAGE:.status.conditions[0].message

# Force reconciliation in dependency order
flux reconcile kustomization infrastructure --with-source
```

### LoadBalancer IP Issues

```bash
# Check if service has external IP
kubectl get svc -n traefik-system traefik-system-traefik

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
# Check Traefik ingress
kubectl get ingressroutes -A
kubectl describe ingressroute <route-name> -n <namespace>

# Test connectivity to LoadBalancer IP
curl -v http://10.10.7.200
curl -v https://10.10.7.200

# Check Traefik logs
kubectl logs -n traefik-system -l app.kubernetes.io/name=traefik
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

Point these domains to `10.10.7.200` (Traefik LoadBalancer IP):

- `*.home.cwbtech.net` (wildcard)
- Or individual entries:
  - `prometheus.home.cwbtech.net`
  - `grafana.home.cwbtech.net`
  - `traefik.home.cwbtech.net`

### Firewall Rules

For external access, forward ports to `10.10.7.200`:

- Port 80 → 10.10.7.200:80 (HTTP)
- Port 443 → 10.10.7.200:443 (HTTPS)

## Monitoring and Maintenance

### Resource Usage

```bash
# Check resource consumption
kubectl top nodes
kubectl top pods -A | grep -E "(metallb|traefik|prometheus|grafana)"
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

## Performance Tuning

- **MetalLB**: Minimal overhead, scales with number of services
- **Traefik**: 2 replicas for HA, anti-affinity rules
- **Prometheus**: 15-day retention, 50GB storage
- **Grafana**: Configured for efficient query caching

## References

- [FluxCD Documentation](https://fluxcd.io/docs/)
- [MetalLB Documentation](https://metallb.universe.tf/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Cert Manager Documentation](https://cert-manager.io/docs/)
- [Sealed Secrets Documentation](https://sealed-secrets.netlify.app/)
