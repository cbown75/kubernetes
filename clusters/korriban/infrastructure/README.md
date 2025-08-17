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
│   Traefik       │    │  Storage CSI     │    │  Prometheus     │
│   (Ingress)     │────│  (Persistent)    │────│  (Monitoring)   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Deployment Order

The infrastructure components are deployed in dependency order:

1. **Storage** - NFS & Synology CSI drivers
2. **Sealed Secrets** - Secret encryption and management
3. **Cert Manager** - TLS certificate automation
4. **Traefik** - Ingress controller and load balancer
5. **Prometheus** - Monitoring and metrics collection

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

### 4. Traefik Ingress Controller

- **Purpose**: HTTP/HTTPS ingress and load balancing
- **Namespace**: `traefik-system`
- **Features**:
  - Automatic service discovery
  - TLS termination
  - Dashboard and API
  - Metrics export

### 5. Prometheus Monitoring

- **Purpose**: Metrics collection and monitoring
- **Namespace**: `monitoring`
- **Features**:
  - Metrics scraping
  - Time-series database
  - Web UI with queries
  - Persistent storage

## Quick Status Checks

### All Components Status

```bash
# Check all infrastructure kustomizations
kubectl get kustomizations -n flux-system

# Check all namespaces
kubectl get namespaces | grep -E "(flux-system|cert-manager|traefik-system|monitoring|nfs-csi-driver)"

# Check all pods across infrastructure namespaces
kubectl get pods -A | grep -E "(flux-system|cert-manager|traefik-system|monitoring|nfs-csi-driver)"
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

#### Traefik

```bash
# Traefik status
kubectl get pods -n traefik-system
kubectl get svc -n traefik-system
kubectl get ingressroutes -A
```

#### Storage

```bash
# Storage drivers
kubectl get pods -n nfs-csi-driver
kubectl get pods -n kube-system | grep synology
kubectl get storageclasses
```

#### Prometheus

```bash
# Prometheus monitoring
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
flux reconcile kustomization flux-system
kubectl wait --for=condition=ready kustomization/flux-system -n flux-system --timeout=300s
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

# Check Traefik logs
kubectl logs -n traefik-system -l app.kubernetes.io/name=traefik
```

## Configuration Management

### GitOps Workflow

All infrastructure changes must go through Git:

1. **Edit YAML files** in the infrastructure directory
2. **Commit and push** to main branch
3. **FluxCD automatically applies** changes within 1 minute
4. **Monitor status** with `kubectl get kustomizations -A`

### Infrastructure Modifications

To modify infrastructure components:

```bash
# Check current configuration
kubectl get kustomization <component> -n flux-system -o yaml

# Edit source files in Git repository
git checkout -b infrastructure-update
# Make changes to YAML files
git add .
git commit -m "Update infrastructure component"
git push origin infrastructure-update

# Monitor deployment after merge
kubectl get kustomizations -A -w
```

## Security Considerations

### Network Policies

Infrastructure components use network policies to restrict traffic:

```bash
# Check network policies
kubectl get networkpolicies -A

# Verify traffic flow
kubectl exec -n <source-namespace> <pod> -- nc -zv <target-service> <port>
```

### RBAC

Components use least-privilege RBAC:

```bash
# Check service accounts
kubectl get serviceaccounts -A | grep -E "(flux|cert-manager|traefik|prometheus)"

# Check cluster roles
kubectl get clusterroles | grep -E "(flux|cert-manager|traefik|prometheus)"
```

### Secret Management

All secrets are encrypted using Sealed Secrets:

```bash
# List sealed secrets
kubectl get sealedsecrets -A

# Verify secret decryption
kubectl get secrets -A | grep -v kubernetes.io
```

## Monitoring and Alerts

### Prometheus Metrics

Access Prometheus dashboard:

```bash
# Port forward to Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Open http://localhost:9090
```

### Traefik Dashboard

Access Traefik dashboard:

```bash
# Port forward to Traefik
kubectl port-forward -n traefik-system svc/traefik 9000:9000
# Open http://localhost:9000/dashboard/
```

### Log Aggregation

View logs from all infrastructure components:

```bash
# FluxCD logs
kubectl logs -n flux-system -l app.kubernetes.io/part-of=flux

# Cert Manager logs
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager

# Traefik logs
kubectl logs -n traefik-system -l app.kubernetes.io/name=traefik
```

## Backup and Recovery

### Configuration Backup

All configuration is stored in Git, but also backup critical resources:

```bash
# Backup FluxCD configuration
kubectl get kustomizations -A -o yaml > backup/kustomizations.yaml
kubectl get gitrepositories -A -o yaml > backup/gitrepositories.yaml

# Backup certificates
kubectl get certificates -A -o yaml > backup/certificates.yaml

# Backup storage classes
kubectl get storageclasses -o yaml > backup/storageclasses.yaml
```

### Disaster Recovery

In case of cluster failure:

1. **Restore cluster** to working state
2. **Bootstrap FluxCD** with original repository
3. **Verify component deployment** order
4. **Check all dependencies** are satisfied
5. **Test application functionality**

## Maintenance

### Update Procedures

To update infrastructure components:

1. **Check for new versions** of Helm charts or images
2. **Test updates** in a development environment
3. **Update configuration** in Git repository
4. **Monitor deployment** through FluxCD
5. **Verify functionality** after updates

### Health Monitoring

Regular health checks:

```bash
# Daily infrastructure check
./scripts/infrastructure-health-check.sh

# Weekly dependency audit
kubectl get kustomizations -A --sort-by=.metadata.creationTimestamp
```

## Support and Documentation

- **FluxCD**: https://fluxcd.io/docs/
- **Cert Manager**: https://cert-manager.io/docs/
- **Traefik**: https://doc.traefik.io/traefik/
- **Prometheus**: https://prometheus.io/docs/
- **Kubernetes CSI**: https://kubernetes-csi.github.io/docs/
