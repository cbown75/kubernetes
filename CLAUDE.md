# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a **GitOps-based Kubernetes infrastructure** repository managed by **FluxCD v2**. All cluster configuration is declared in YAML manifests, and FluxCD automatically reconciles the cluster state to match Git within 1 minute. Manual kubectl changes are automatically reverted.

**Critical:** This repository contains NO application code - only Kubernetes manifests (raw YAML, Kustomizations, and HelmReleases).

## Common Commands

### Validation
```bash
# Validate YAML syntax before committing
kubectl apply --dry-run=client -f <file>

# Validate entire kustomization
kubectl kustomize clusters/korriban/ --enable-helm

# Check FluxCD reconciliation status
flux get all
kubectl get kustomizations -A
```

### Monitoring FluxCD
```bash
# Overall health check
flux get all

# Watch real-time changes
kubectl get kustomizations -A -w

# Force reconciliation (useful after pushing changes)
flux reconcile kustomization flux-system

# Check FluxCD controller logs
kubectl logs -n flux-system -l app=kustomize-controller
kubectl logs -n flux-system -l app=helm-controller
```

### Debugging Deployments
```bash
# Check infrastructure components
kubectl get pods -A | grep -E "(flux-system|cert-manager|istio-system|monitoring|metallb-system)"

# Investigate stuck kustomization
kubectl describe kustomization <name> -n flux-system

# Check application pods
kubectl get pods -n monitoring

# View service endpoints
kubectl get virtualservice -A
kubectl get gateway -A
kubectl get svc -n istio-system
```

### Secret Management
```bash
# Generate sealed secrets (use scripts)
./scripts/create-grafana-secrets.sh
./scripts/create-alertmanager-secrets.sh

# Verify sealed secret decryption
kubectl get secret <secret-name> -n <namespace> -o yaml

# Check sealed secrets controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets
```

## Architecture

### Repository Structure

```
kubernetes/
├── clusters/korriban/                    # Cluster-specific entry point
│   ├── flux-system/                      # FluxCD controllers & sync config
│   │   ├── gotk-components.yaml          # FluxCD installation
│   │   ├── gotk-sync.yaml                # Git sync configuration
│   │   ├── kustomization-infrastructure.yaml  # Infrastructure reconciliation
│   │   └── kustomization-apps.yaml       # Apps reconciliation (depends on infra)
│   ├── infrastructure/                   # Infrastructure layer
│   │   └── kustomization.yaml            # Declares dependency order
│   └── kustomization.yaml                # Root cluster manifest
│
├── infrastructure/                       # Shared infrastructure Helm charts
│   ├── storage/                          # NFS & Synology CSI Helm charts
│   ├── cert-manager/                     # TLS cert automation (base/overlay)
│   ├── metallb/                          # LoadBalancer (base/overlay)
│   ├── istio/                            # Service mesh (base/overlay)
│   └── cilium/                           # CNI networking (base/overlay)
│
├── apps/                                 # Application deployments
│   ├── grafana/                          # Monitoring dashboard
│   ├── prometheus/                       # Metrics collection
│   ├── loki/                             # Log aggregation
│   ├── alertmanager/                     # Alert routing
│   └── alloy/                            # Telemetry collector
│
└── scripts/                              # Sealed secret generation scripts
    └── create-*-secrets.sh               # Generate sealed secrets for apps
```

### FluxCD Reconciliation Flow

1. **flux-system** (FluxCD controllers) continuously polls Git every 1 minute
2. **infrastructure** kustomization deploys in dependency order:
   - Storage (NFS CSI, Synology CSI)
   - Sealed Secrets (secret encryption)
   - Cilium (CNI networking)
   - DNS (CoreDNS configuration)
   - Cert Manager, MetalLB, Istio (deployed in parallel from `clusters/korriban/kustomization.yaml`)
3. **apps** kustomization waits for infrastructure, then deploys monitoring stack

### Base/Overlay Pattern

Most components use Kustomize base/overlay structure:

```
infrastructure/<component>/
├── base/
│   ├── kustomization.yaml       # Common resources
│   └── release.yaml             # HelmRelease definition
└── overlay/
    └── korriban/
        ├── kustomization.yaml   # Cluster-specific patches
        ├── config.yaml          # Values override
        └── sealed-secrets.yaml  # Encrypted secrets
```

Apps follow the same pattern in `apps/<app-name>/`.

### Dependency Management

Infrastructure components have strict ordering defined in `clusters/korriban/infrastructure/kustomization.yaml`:
1. Storage (required first)
2. Sealed Secrets (required for secret decryption)
3. Cilium (CNI networking)
4. DNS

Other infrastructure (cert-manager, metallb, istio) is declared in `clusters/korriban/kustomization.yaml` and deploys after infrastructure is ready.

### Network Architecture

- **MetalLB IP Pool:** 10.10.7.200-250
- **Istio Ingress LoadBalancer:** 10.10.7.210 (main entry point)
- **DNS:** `*.home.cwbtech.net` → 10.10.7.210
- **TLS:** Automatic Let's Encrypt certificates via cert-manager + Cloudflare DNS-01

## Development Workflow

### Making Changes

1. **Edit YAML files** in your local clone
2. **Validate changes:**
   ```bash
   kubectl apply --dry-run=client -f <file>
   ```
3. **Commit and push** to main branch:
   ```bash
   git add <files>
   git commit -m "descriptive message"
   git push
   ```
4. **Monitor FluxCD reconciliation:**
   ```bash
   kubectl get kustomizations -A -w
   ```

### Adding New Applications

1. **Create app structure:**
   ```bash
   mkdir -p apps/<app-name>/{base,overlay/korriban}
   ```

2. **Create base resources** in `apps/<app-name>/base/`:
   - `kustomization.yaml` (list all resources)
   - Kubernetes manifests (deployment, service, etc.)
   - Use `commonLabels` for consistent labeling

3. **Create overlay** in `apps/<app-name>/overlay/korriban/`:
   - `kustomization.yaml` (reference base, add patches)
   - `sealed-secrets.yaml` (if needed, use scripts to generate)

4. **Add to cluster kustomization:**
   ```yaml
   # clusters/korriban/apps/kustomization.yaml
   resources:
     - <app-name>
   ```

5. **Create Istio VirtualService** (if exposing via ingress):
   ```yaml
   # apps/<app-name>/base/virtualservice.yaml
   apiVersion: networking.istio.io/v1beta1
   kind: VirtualService
   metadata:
     name: <app-name>
     namespace: <namespace>
   spec:
     hosts:
       - "<app-name>.home.cwbtech.net"
     gateways:
       - istio-system/main-gateway
     http:
       - route:
           - destination:
               host: <app-name>
               port:
                 number: <port>
   ```

### Sealed Secrets

**Never commit plain text secrets.** Use sealed secrets:

1. **Run generation script:**
   ```bash
   ./scripts/create-<app>-secrets.sh
   ```

2. **Script prompts for secrets** (passwords, API keys, etc.)

3. **Output generated** at `apps/<app>/overlay/korriban/sealed-secrets.yaml`

4. **Commit encrypted file** (safe to commit)

**Creating new secret script:**
- See `scripts/README.md` for script patterns
- Use `kubeseal` to encrypt secrets
- Output to `apps/<app>/overlay/korriban/sealed-secrets.yaml`

### Emergency Procedures

If FluxCD is causing issues and you need manual cluster access:

```bash
# Temporarily disable FluxCD reconciliation
kubectl scale deployment -n flux-system kustomize-controller --replicas=0

# Make manual changes...

# Update Git to match manual changes

# Re-enable FluxCD
kubectl scale deployment -n flux-system kustomize-controller --replicas=1
```

## YAML Style Guidelines

- **Indentation:** 2 spaces (no tabs)
- **Resource naming:** kebab-case (`grafana-admin-secret`)
- **Namespace:** Always explicit in metadata for namespaced resources
- **Labels:** Required on all resources:
  ```yaml
  labels:
    app.kubernetes.io/name: <app-name>
    app.kubernetes.io/part-of: <subsystem>
  ```
- **Resource limits:** Always specify for production workloads:
  ```yaml
  resources:
    requests:
      memory: "128Mi"
      cpu: "100m"
    limits:
      memory: "256Mi"
      cpu: "200m"
  ```
- **Security contexts:** Include on deployments:
  ```yaml
  securityContext:
    runAsNonRoot: true
    readOnlyRootFilesystem: true
    allowPrivilegeEscalation: false
  ```

## Key Concepts

### HelmRelease Resources

Many components use Flux HelmRelease CRDs instead of raw manifests:

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: <release-name>
  namespace: <namespace>
spec:
  interval: 30m
  chart:
    spec:
      chart: <chart-name>
      version: <version>
      sourceRef:
        kind: HelmRepository
        name: <repo-name>
        namespace: flux-system
  values:
    # Helm values here
```

### Kustomization CRDs

FluxCD Kustomizations (different from `kustomization.yaml` files) define how to apply manifests:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: <name>
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./clusters/korriban/<path>
  prune: true          # Delete resources removed from Git
  wait: true           # Wait for resources to be ready
  timeout: 10m
  dependsOn:           # Dependency on other kustomizations
    - name: infrastructure
```

### Network Policies

Many namespaces include NetworkPolicies for traffic isolation. When adding apps, consider:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: <app-name>-netpol
  namespace: <namespace>
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: <app-name>
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: istio-system
  egress:
    - to:
        - namespaceSelector: {}
```

## Common Issues

### Kustomization Stuck in "Ready: False"

```bash
# Describe to see error
kubectl describe kustomization <name> -n flux-system

# Common causes:
# - YAML syntax error
# - Missing dependency
# - Resource conflict
# - HelmRepository not ready
```

### Service Not Accessible

```bash
# Check Istio resources
kubectl get virtualservice -A
kubectl get gateway -A
kubectl get svc -n istio-system istio-ingressgateway

# Verify ingress IP
kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
# Should be: 10.10.7.210
```

### Certificate Issues

```bash
# Check certificate status
kubectl get certificates -A

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Verify ClusterIssuer
kubectl describe clusterissuer letsencrypt-cloudflare

# Common issues:
# - Cloudflare API token incorrect (sealed secret)
# - DNS not propagated
# - Rate limiting from Let's Encrypt
```

### Sealed Secret Not Decrypting

```bash
# Check sealed-secrets controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets
kubectl logs -n kube-system -l app.kubernetes.io/name=sealed-secrets

# Verify SealedSecret resource exists
kubectl get sealedsecrets -A

# Check if secret was created
kubectl get secret <secret-name> -n <namespace>

# Common issues:
# - Sealed secret encrypted with wrong cluster certificate
# - Controller not running
# - Namespace mismatch
```

## Important Constraints

1. **All changes go through Git** - manual kubectl changes are reverted by FluxCD
2. **Dependencies matter** - infrastructure must deploy before apps
3. **Secrets must be sealed** - never commit plaintext secrets
4. **Istio is the ingress** - all external traffic goes through istio-ingressgateway (10.10.7.210)
5. **Reconciliation is automatic** - changes apply within 1 minute after Git push
6. **Namespace isolation** - apps are isolated by NetworkPolicies
7. **TLS is automatic** - cert-manager handles Let's Encrypt certificates for Istio VirtualServices

## Cluster Context

- **Cluster Name:** korriban
- **Primary Domain:** `*.home.cwbtech.net`
- **Certificate Issuer:** Let's Encrypt (Cloudflare DNS-01 challenge)
- **Ingress:** Istio (10.10.7.210)
- **Monitoring:** Prometheus, Grafana, Loki, Alloy, Tempo, Pyroscope
- **Storage:** NFS CSI + Synology CSI drivers
