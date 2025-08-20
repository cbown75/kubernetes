# Prometheus for Korriban Cluster

## Overview

Prometheus deployment using the official `prometheus-community/prometheus` Helm chart. This provides metrics collection and storage for the monitoring stack with comprehensive Kubernetes monitoring.

## Chart Information

- **Chart**: `prometheus-community/prometheus`
- **Version**: `>=25.0.0`
- **App Version**: `v2.51.2`
- **Repository**: https://prometheus-community.github.io/helm-charts

## Features

- **Complete Kubernetes Monitoring**: Auto-discovery of nodes, pods, and services
- **High Performance Storage**: Uses Synology CSI (`synology-holocron-fast`)
- **Security Hardened**: Non-root containers with security contexts
- **TLS Integration**: Automatic HTTPS with Cert Manager
- **No Authentication**: Direct access for internal monitoring
- **Resource Management**: 4Gi memory limit, 50Gi storage
- **Data Retention**: 15-day retention with 45GB size limit

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Prometheus    │────│   Target         │────│   Metrics       │
│   (Server)      │    │   Discovery      │    │   (Endpoints)   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Monitoring Targets

### Automatic Service Discovery

Prometheus automatically discovers and monitors:

- **Kubernetes API Server**: Cluster health and performance
- **Node Exporter**: Host-level metrics (CPU, memory, disk, network)
- **cAdvisor**: Container-level metrics from kubelet
- **Kubelet**: Node and pod resource metrics
- **Annotated Services**: Services with `prometheus.io/scrape: "true"`
- **Annotated Pods**: Pods with `prometheus.io/scrape: "true"`

### Scrape Jobs Configured

1. **prometheus** - Self-monitoring
2. **kubernetes-apiservers** - API server metrics
3. **node-exporter** - Host metrics via node discovery (port 9100)
4. **kubernetes-services** - Service discovery via annotations
5. **kubernetes-cadvisor** - Container metrics via kubelet proxy
6. **kubernetes-nodes** - Node metrics via kubelet proxy
7. **kubernetes-pods** - Pod discovery via annotations

## Access

- **URL**: https://prometheus.home.cwbtech.net
- **Authentication**: None (direct access)
- **TLS**: Automatic Let's Encrypt certificate via Cert Manager

## Configuration

### Storage

- **Storage Class**: `synology-holocron-fast` (high-performance NVMe)
- **Size**: 50Gi per instance
- **Access Mode**: ReadWriteOnce
- **Retention**: 15 days / 45GB (whichever comes first)

### Resources

```yaml
resources:
  limits:
    cpu: 2000m
    memory: 4Gi
  requests:
    cpu: 500m
    memory: 2Gi
```

### Security Context

- **User**: 65534 (nobody)
- **Non-root**: true
- **Read-only filesystem**: true
- **Dropped capabilities**: ALL
- **Seccomp profile**: RuntimeDefault

## Integration with Monitoring Stack

### AlertManager Integration

Prometheus sends alerts to AlertManager for:

- Node health and resource usage
- Pod failures and restarts
- Storage capacity warnings
- Kubernetes component health

### Grafana Integration

Grafana queries Prometheus for:

- Infrastructure dashboards
- Application metrics
- Custom monitoring visualizations
- Real-time metric exploration

### Node Exporter Integration

Discovers Node Exporter instances via:

- **Role**: `node` (Kubernetes node discovery)
- **Target**: `{node_ip}:9100`
- **Relabeling**: Maps node labels to metric labels

## Key Metrics Available

### Infrastructure Metrics

```promql
# Node availability
up{job="node-exporter"}

# CPU usage by node
rate(node_cpu_seconds_total[5m])

# Memory usage
node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes

# Disk usage
(node_filesystem_size_bytes - node_filesystem_avail_bytes) / node_filesystem_size_bytes
```

### Kubernetes Metrics

```promql
# Pod CPU usage
rate(container_cpu_usage_seconds_total[5m])

# Pod memory usage
container_memory_working_set_bytes

# Pod restart rate
rate(kube_pod_container_status_restarts_total[5m])
```

### Cluster Health

```promql
# API server availability
up{job="kubernetes-apiservers"}

# Node readiness
kube_node_status_condition{condition="Ready"}

# Cluster capacity
cluster:node_cpu:ratio
cluster:node_memory:ratio
```

## Deployment

### Prerequisites

- Kubernetes cluster with RBAC enabled
- Traefik ingress controller
- Cert Manager for TLS certificates
- Synology CSI driver
- Node Exporter deployed separately

### Installation

The deployment is managed by FluxCD:

```bash
# Check deployment status
kubectl get helmrelease prometheus -n monitoring

# Check pod status
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus-server

# Check service status
kubectl get svc -n monitoring prometheus-server
```

### Sealed Secrets

Generate sealed secrets (placeholder for future use):

```bash
# Run the script to create sealed secrets
./scripts/create-prometheus-secrets.sh

# Commit the generated sealed secret
git add clusters/korriban/apps/prometheus/sealed-secret.yaml
git commit -m "Add Prometheus sealed secrets"
git push
```

## Troubleshooting

### Common Issues

#### **Pod Not Starting**

```bash
# Check pod events
kubectl describe pod -n monitoring -l app.kubernetes.io/name=prometheus-server

# Check logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus-server
```

**Common causes:**

- Storage class not available
- Insufficient resources
- Configuration errors

#### **Targets Not Discovered**

```bash
# Check service discovery
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health != "up")'

# Port forward to access Prometheus
kubectl port-forward -n monitoring svc/prometheus-server 9090:80
```

**Solutions:**

- Verify RBAC permissions
- Check network policies
- Validate service annotations

#### **Storage Issues**

```bash
# Check PVC status
kubectl get pvc -n monitoring

# Check storage class
kubectl get storageclass synology-holocron-fast

# Check disk usage in pod
kubectl exec -n monitoring deployment/prometheus-server -- df -h /prometheus
```

### Useful Commands

```bash
# Port forward to access Prometheus UI
kubectl port-forward -n monitoring svc/prometheus-server 9090:80
# Then visit: http://localhost:9090

# Check configuration
kubectl exec -n monitoring deployment/prometheus-server -- cat /etc/config/prometheus.yml

# Reload configuration (if web.enable-lifecycle is enabled)
curl -X POST http://localhost:9090/-/reload

# Check health
curl http://localhost:9090/-/healthy

# Query metrics via API
curl -G 'http://localhost:9090/api/v1/query' --data-urlencode 'query=up'
```

## Monitoring Prometheus Itself

Key metrics to monitor Prometheus health:

```promql
# Prometheus up
up{job="prometheus"}

# Time series ingested per second
rate(prometheus_tsdb_symbol_table_size_bytes[5m])

# Query duration
histogram_quantile(0.99, rate(prometheus_engine_query_duration_seconds_bucket[5m]))

# Storage usage
prometheus_tsdb_size_bytes

# Rule evaluation duration
rate(prometheus_rule_evaluation_duration_seconds_sum[5m])
```

## Performance Tuning

### Memory Optimization

```yaml
# Adjust retention for memory usage
server:
  retention: "7d" # Reduce retention time
  retentionSize: "20GB" # Reduce retention size
```

### Query Performance

- Use recording rules for expensive queries
- Optimize PromQL queries with proper selectors
- Consider federation for large deployments

### Storage Optimization

- Use fast storage for better performance
- Monitor disk I/O and adjust retention
- Consider external storage for long-term retention

## Integration Examples

### Custom Service Discovery

Add annotation to services for automatic discovery:

```yaml
apiVersion: v1
kind: Service
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/metrics"
spec:
  # ... service configuration
```

### Custom Pod Discovery

Add annotation to pods for automatic discovery:

```yaml
apiVersion: v1
kind: Pod
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/metrics"
spec:
  # ... pod configuration
```

## Resources

- **Prometheus Documentation**: https://prometheus.io/docs/
- **PromQL Guide**: https://prometheus.io/docs/prometheus/latest/querying/
- **Chart Documentation**: https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus
- **Best Practices**: https://prometheus.io/docs/practices/
- **Kubernetes Monitoring**: https://prometheus.io/docs/guides/kubernetes/
