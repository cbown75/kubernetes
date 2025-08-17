# Prometheus Helm Chart

## Overview

This Helm chart deploys Prometheus as part of the monitoring stack for Kubernetes clusters. It's designed to work with FluxCD and integrates with the existing infrastructure components like Traefik and Cert Manager.

## Chart Information

- **Chart Name**: `prometheus`
- **Chart Version**: `1.0.0`
- **App Version**: `2.51.2`
- **Prometheus Image**: `docker.io/prom/prometheus:v2.51.2`

## Features

- **High Performance Storage**: Uses Synology CSI for fast SSD storage
- **Security Hardened**: Non-root containers with security contexts
- **TLS Integration**: Automatic HTTPS with Cert Manager
- **Authentication**: Basic auth protection via Sealed Secrets
- **Network Policies**: Restricted network access
- **Resource Management**: Proper CPU and memory limits
- **Data Retention**: 15-day retention with 45GB size limit

## Installation

### Prerequisites

- Kubernetes cluster v1.20+
- Helm v3.0+
- Synology CSI driver installed
- Traefik ingress controller
- Cert Manager for TLS certificates
- Sealed Secrets for authentication

### Using FluxCD (Recommended)

This chart is designed to be deployed via FluxCD. See the HelmRelease in `clusters/korriban/infrastructure/prometheus/release.yaml`.

### Manual Installation

```bash
# Add dependencies (if installing manually)
helm dependency update

# Install the chart
helm install prometheus . \
  --namespace monitoring \
  --create-namespace \
  --values values.yaml
```

## Configuration

### Default Values

The chart comes with production-ready defaults:

```yaml
prometheus:
  replicaCount: 1
  image:
    registry: docker.io
    repository: prom/prometheus
    tag: "v2.51.2"
    pullPolicy: IfNotPresent

  resources:
    limits:
      cpu: 2000m
      memory: 4Gi
    requests:
      cpu: 500m
      memory: 2Gi

  persistence:
    enabled: true
    storageClass: "synology-holocron-fast"
    accessMode: ReadWriteOnce
    size: 50Gi
```

### Storage Configuration

The chart uses high-performance Synology storage by default:

```yaml
global:
  storageClass: "synology-holocron-fast"

prometheus:
  persistence:
    enabled: true
    storageClass: "synology-holocron-fast"
    size: 50Gi
```

### Security Configuration

Security contexts are enforced for non-root operation:

```yaml
prometheus:
  podSecurityContext:
    fsGroup: 65534
    runAsNonRoot: true
    runAsUser: 65534
    seccompProfile:
      type: RuntimeDefault

  securityContext:
    allowPrivilegeEscalation: false
    capabilities:
      drop: ["ALL"]
    readOnlyRootFilesystem: true
    runAsNonRoot: true
    runAsUser: 65534
```

### Ingress Configuration

HTTPS ingress with authentication:

```yaml
ingress:
  enabled: true
  className: "traefik"
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    traefik.ingress.kubernetes.io/router.middlewares: monitoring-prometheus-auth@kubernetescrd
    cert-manager.io/cluster-issuer: letsencrypt-cloudflare
  hosts:
    - host: prometheus.home.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: prometheus-tls
      hosts:
        - prometheus.home.example.com
```

### Data Retention

Prometheus is configured with practical retention policies:

```yaml
prometheus:
  extraArgs:
    - --storage.tsdb.retention.time=15d
    - --storage.tsdb.retention.size=45GB
    - --storage.tsdb.wal-compression
```

## Values Reference

### Global Settings

| Parameter              | Description            | Default                    |
| ---------------------- | ---------------------- | -------------------------- |
| `global.imageRegistry` | Global Docker registry | `""`                       |
| `global.storageClass`  | Global storage class   | `"synology-holocron-fast"` |

### Prometheus Settings

| Parameter                     | Description                   | Default           |
| ----------------------------- | ----------------------------- | ----------------- |
| `prometheus.replicaCount`     | Number of Prometheus replicas | `1`               |
| `prometheus.image.registry`   | Prometheus image registry     | `docker.io`       |
| `prometheus.image.repository` | Prometheus image repository   | `prom/prometheus` |
| `prometheus.image.tag`        | Prometheus image tag          | `"v2.51.2"`       |
| `prometheus.image.pullPolicy` | Image pull policy             | `IfNotPresent`    |

### Resource Settings

| Parameter                              | Description    | Default |
| -------------------------------------- | -------------- | ------- |
| `prometheus.resources.limits.cpu`      | CPU limit      | `2000m` |
| `prometheus.resources.limits.memory`   | Memory limit   | `4Gi`   |
| `prometheus.resources.requests.cpu`    | CPU request    | `500m`  |
| `prometheus.resources.requests.memory` | Memory request | `2Gi`   |

### Storage Settings

| Parameter                             | Description               | Default                    |
| ------------------------------------- | ------------------------- | -------------------------- |
| `prometheus.persistence.enabled`      | Enable persistent storage | `true`                     |
| `prometheus.persistence.storageClass` | Storage class for PVC     | `"synology-holocron-fast"` |
| `prometheus.persistence.accessMode`   | PVC access mode           | `ReadWriteOnce`            |
| `prometheus.persistence.size`         | PVC size                  | `50Gi`                     |

### Ingress Settings

| Parameter             | Description         | Default         |
| --------------------- | ------------------- | --------------- |
| `ingress.enabled`     | Enable ingress      | `true`          |
| `ingress.className`   | Ingress class name  | `"traefik"`     |
| `ingress.annotations` | Ingress annotations | See values.yaml |

### Security Settings

| Parameter                                  | Description               | Default |
| ------------------------------------------ | ------------------------- | ------- |
| `prometheus.podSecurityContext.runAsUser`  | User ID to run containers | `65534` |
| `prometheus.podSecurityContext.runAsGroup` | Group ID for containers   | `65534` |
| `prometheus.podSecurityContext.fsGroup`    | Filesystem group ID       | `65534` |

### Network Policy Settings

| Parameter               | Description             | Default         |
| ----------------------- | ----------------------- | --------------- |
| `networkPolicy.enabled` | Enable network policies | `true`          |
| `networkPolicy.ingress` | Ingress rules           | See values.yaml |

## Usage Examples

### Custom Storage Size

```yaml
prometheus:
  persistence:
    size: 100Gi
```

### Different Storage Class

```yaml
global:
  storageClass: "fast-ssd"
```

### Custom Resource Limits

```yaml
prometheus:
  resources:
    limits:
      cpu: 4000m
      memory: 8Gi
    requests:
      cpu: 1000m
      memory: 4Gi
```

### Custom Retention

```yaml
prometheus:
  extraArgs:
    - --storage.tsdb.retention.time=30d
    - --storage.tsdb.retention.size=90GB
```

## Monitoring and Health Checks

The chart includes health checks:

```yaml
prometheus:
  probes:
    liveness:
      httpGet:
        path: /-/healthy
        port: http
      initialDelaySeconds: 30
      timeoutSeconds: 10
    readiness:
      httpGet:
        path: /-/ready
        port: http
      initialDelaySeconds: 30
      timeoutSeconds: 10
```

## Troubleshooting

### Chart Installation Issues

```bash
# Check Helm release status
helm status prometheus -n monitoring

# View Helm release history
helm history prometheus -n monitoring

# Check for template rendering issues
helm template prometheus . --debug
```

### Pod Issues

```bash
# Check pod status
kubectl get pods -n monitoring

# Check pod logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus

# Describe pod for events
kubectl describe pod -n monitoring -l app.kubernetes.io/name=prometheus
```

### Storage Issues

```bash
# Check PVC status
kubectl get pvc -n monitoring

# Check storage class
kubectl get sc synology-holocron-fast

# Check PV binding
kubectl get pv | grep prometheus
```

### Ingress Issues

```bash
# Check ingress status
kubectl get ingress -n monitoring

# Check certificate status
kubectl get certificate -n monitoring

# Test connectivity
curl -k https://prometheus.home.example.com/-/healthy
```

## Upgrading

### Version Compatibility

| Chart Version | Prometheus Version | Kubernetes Version |
| ------------- | ------------------ | ------------------ |
| 1.0.0         | 2.51.2             | 1.20+              |

### Upgrade Process

```bash
# Update chart dependencies
helm dependency update

# Upgrade release
helm upgrade prometheus . \
  --namespace monitoring \
  --reuse-values

# Verify upgrade
kubectl rollout status deployment/prometheus -n monitoring
```

### Breaking Changes

When upgrading, check for:

- Prometheus version compatibility
- Storage class changes
- Security context updates
- Configuration format changes

## Development

### Testing

```bash
# Lint the chart
helm lint .

# Test template rendering
helm template prometheus . --debug

# Test with different values
helm template prometheus . -f test-values.yaml
```

### Chart Structure

```
.
├── Chart.yaml          # Chart metadata
├── values.yaml         # Default configuration values
├── templates/          # Kubernetes manifests
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── pvc.yaml
│   ├── networkpolicy.yaml
│   ├── serviceaccount.yaml
│   └── _helpers.tpl
└── README.md          # This file
```

## Security Considerations

1. **Non-root execution**: All containers run as non-root user
2. **Read-only filesystem**: Root filesystem is read-only
3. **Dropped capabilities**: All Linux capabilities dropped
4. **Network policies**: Restricted network access
5. **Authentication**: Basic auth protection
6. **TLS encryption**: HTTPS-only access

## Best Practices

1. **Resource limits**: Always set CPU and memory limits
2. **Persistent storage**: Use high-performance storage for metrics
3. **Retention policies**: Configure appropriate data retention
4. **Monitoring**: Monitor Prometheus itself
5. **Backups**: Regular backup of configuration and data
6. **Updates**: Keep Prometheus version current

## Support

- **Prometheus Documentation**: https://prometheus.io/docs/
- **Helm Documentation**: https://helm.sh/docs/
- **Chart Issues**: Submit issues to repository
- **Configuration Help**: Check values.yaml comments
