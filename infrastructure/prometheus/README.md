# Prometheus Monitoring Stack

## Overview

Prometheus is the core monitoring and alerting system for the `korriban` cluster. It collects metrics from various sources, stores them in a time-series database, and provides a powerful query interface.

## Features

- **Time-Series Database**: Efficient storage and retrieval of metrics
- **Service Discovery**: Automatic discovery of monitoring targets
- **PromQL**: Powerful query language for metrics analysis
- **Web Interface**: Built-in web UI for queries and visualization
- **Alerting**: Integration with Alertmanager for notifications
- **Retention**: Configurable data retention policies

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Targets       │    │   Prometheus     │    │   Storage       │
│   (metrics)     │────│   (scraper)      │────│   (TSDB)        │
└─────────────────┘    └──────────────────┘    └─────────────────┘
          │                        │                        │
          ▼                        ▼                        ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Services      │    │   PromQL         │    │   Synology      │
│   Pods          │────│   (queries)      │────│   Fast SSD      │
│   Nodes         │    │                  │    │   50GB Volume   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Configuration

### Storage Configuration

Prometheus uses high-performance Synology storage:

```yaml
persistence:
  enabled: true
  storageClass: "synology-holocron-fast"
  accessMode: ReadWriteOnce
  size: 50Gi
```

### Retention Policy

```yaml
extraArgs:
  - --storage.tsdb.retention.time=15d
  - --storage.tsdb.retention.size=45GB
  - --storage.tsdb.wal-compression
```

### Resource Limits

```yaml
resources:
  limits:
    cpu: 2000m
    memory: 4Gi
  requests:
    cpu: 500m
    memory: 2Gi
```

## Access

### Web Interface

Access Prometheus through secure ingress:

```bash
# URL: https://prometheus.home.example.com
# Authentication: Basic auth (configured via SealedSecret)
```

### Port Forwarding (Development)

```bash
# Direct access for development
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Open http://localhost:9090
```

## Monitoring Targets

### Automatic Service Discovery

Prometheus automatically discovers and monitors:

- **Kubernetes API Server**: Cluster health and performance
- **Node Exporter**: Host-level metrics (CPU, memory, disk, network)
- **cAdvisor**: Container-level metrics
- **FluxCD Controllers**: GitOps reconciliation metrics
- **Traefik**: Ingress controller metrics
- **Cert Manager**: Certificate management metrics

### Custom Metrics

Services can expose metrics using annotations:

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

## Key Metrics

### Infrastructure Metrics

#### Cluster Health

```promql
# Node availability
up{job="kubernetes-nodes"}

# Cluster capacity
cluster:capacity_cpu_cores:sum
cluster:capacity_memory_bytes:sum
```

#### Storage Metrics

```promql
# Storage usage
kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes

# Persistent volume availability
kube_persistentvolume_status_phase
```

### Application Metrics

#### Pod Health

```promql
# Pod restart rate
rate(kube_pod_container_status_restarts_total[5m])

# Pod resource usage
rate(container_cpu_usage_seconds_total[5m])
container_memory_working_set_bytes
```

#### Network Metrics

```promql
# Network traffic
rate(container_network_receive_bytes_total[5m])
rate(container_network_transmit_bytes_total[5m])
```

### FluxCD Metrics

```promql
# Reconciliation status
gotk_reconcile_condition{type="Ready"}

# Reconciliation duration
histogram_quantile(0.95, gotk_reconcile_duration_seconds_bucket)
```

## Querying with PromQL

### Basic Queries

```promql
# Current CPU usage by pod
rate(container_cpu_usage_seconds_total[5m])

# Memory usage by namespace
sum(container_memory_working_set_bytes) by (namespace)

# Disk usage percentage
(1 - (kubelet_volume_stats_available_bytes / kubelet_volume_stats_capacity_bytes)) * 100
```

### Advanced Queries

```promql
# Top 10 pods by CPU usage
topk(10, rate(container_cpu_usage_seconds_total[5m]))

# Pods with high memory usage (>80%)
(container_memory_working_set_bytes / container_spec_memory_limit_bytes) > 0.8

# Failed pods in last hour
increase(kube_pod_container_status_restarts_total[1h]) > 0
```

### Alert Queries

```promql
# High memory usage alert
(container_memory_working_set_bytes / container_spec_memory_limit_bytes) > 0.9

# Disk space low
(kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes) > 0.85

# FluxCD reconciliation failures
increase(gotk_reconcile_condition{type="Ready",status="False"}[5m]) > 0
```

## Troubleshooting

### Prometheus Health Checks

```bash
# Check Prometheus pod status
kubectl get pods -n monitoring

# Check Prometheus logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus

# Check persistent volume
kubectl get pvc -n monitoring
```

### Common Issues and Solutions

#### High Memory Usage

**Symptoms**: Prometheus pod OOMKilled or high memory usage

**Diagnosis**:

```bash
# Check memory usage
kubectl top pod -n monitoring

# Review retention settings
kubectl logs -n monitoring prometheus-0 | grep retention
```

**Solutions**:

- Reduce retention time
- Increase memory limits
- Optimize query patterns
- Reduce scrape frequency

#### Storage Full

**Symptoms**: "no space left on device" errors

**Diagnosis**:

```bash
# Check disk usage
kubectl exec -n monitoring prometheus-0 -- df -h /prometheus

# Check retention size
kubectl logs -n monitoring prometheus-0 | grep "retention size"
```

**Solutions**:

- Increase volume size
- Reduce retention time
- Clean up old data manually

#### Target Discovery Issues

**Symptoms**: Missing metrics from expected targets

**Diagnosis**:

```bash
# Check target discovery in Prometheus UI
# Go to Status > Targets

# Check service annotations
kubectl get svc -A -o yaml | grep prometheus.io
```

**Solutions**:

- Verify service annotations
- Check network policies
- Verify RBAC permissions

### Debugging Queries

```promql
# Check scrape success rate
rate(prometheus_target_scrapes_total[5m])

# Identify failed targets
up == 0

# Query performance
prometheus_rule_evaluation_duration_seconds
```

## Maintenance

### Backup and Recovery

```bash
# Backup Prometheus configuration
kubectl get prometheus -A -o yaml > backup/prometheus-config-$(date +%Y%m%d).yaml

# Backup persistent volume (if needed)
kubectl exec -n monitoring prometheus-0 -- tar czf /tmp/prometheus-data.tar.gz /prometheus
kubectl cp monitoring/prometheus-0:/tmp/prometheus-data.tar.gz ./prometheus-backup-$(date +%Y%m%d).tar.gz
```

### Volume Expansion

```bash
# Expand Prometheus storage
kubectl patch pvc prometheus-storage -n monitoring -p '{"spec":{"resources":{"requests":{"storage":"80Gi"}}}}'

# Monitor expansion
kubectl get pvc prometheus-storage -n monitoring -w
```

### Performance Optimization

```bash
# Check query performance
kubectl exec -n monitoring prometheus-0 -- promtool query instant 'prometheus_engine_query_duration_seconds{quantile="0.9"}'

# Analyze memory usage
kubectl exec -n monitoring prometheus-0 -- promtool tsdb analyze /prometheus
```

## Security

### Network Policies

Prometheus is protected by network policies:

```yaml
networkPolicy:
  enabled: true
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: traefik-system
      ports:
        - protocol: TCP
          port: 9090
```

### Authentication

Access is protected by basic authentication:

```yaml
sealedSecrets:
  enabled: true
  secrets:
    prometheus-basic-auth:
      auth: "<encrypted-htpasswd>"
```

### RBAC

Prometheus runs with minimal required permissions:

```bash
# Check Prometheus service account permissions
kubectl auth can-i list nodes --as=system:serviceaccount:monitoring:prometheus

# Review cluster role
kubectl describe clusterrole prometheus
```

## Integration

### Traefik Integration

Metrics from Traefik are automatically collected:

```yaml
# Traefik metrics configuration
metrics:
  prometheus:
    addEntryPointsLabels: true
    addServicesLabels: true
    addRoutersLabels: true
```

### FluxCD Integration

FluxCD controllers expose metrics on port 8080:

```promql
# FluxCD reconciliation metrics
gotk_reconcile_duration_seconds
gotk_reconcile_condition
controller_runtime_reconcile_total
```

### Storage Integration

Monitor storage metrics from CSI drivers:

```promql
# Volume usage across storage classes
kubelet_volume_stats_used_bytes{storage_class="synology-holocron-fast"}
```

## Alerting Rules

### Infrastructure Alerts

```yaml
groups:
  - name: infrastructure
    rules:
      - alert: HighMemoryUsage
        expr: (container_memory_working_set_bytes / container_spec_memory_limit_bytes) > 0.9
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage detected"

      - alert: DiskSpaceLow
        expr: (kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes) > 0.85
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Disk space low on volume {{ $labels.persistentvolumeclaim }}"
```

### Application Alerts

```yaml
- name: applications
  rules:
    - alert: PodCrashLooping
      expr: rate(kube_pod_container_status_restarts_total[15m]) * 60 * 15 > 0
      for: 0m
      labels:
        severity: critical
      annotations:
        summary: "Pod {{ $labels.pod }} is crash looping"

    - alert: FluxReconciliationFailure
      expr: gotk_reconcile_condition{type="Ready",status="False"} == 1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "FluxCD reconciliation failed for {{ $labels.kind }}/{{ $labels.name }}"
```

## Best Practices

1. **Resource Planning**: Size Prometheus appropriately for your metrics volume
2. **Retention Strategy**: Balance storage costs with data requirements
3. **Query Optimization**: Use efficient PromQL queries
4. **Regular Backups**: Backup configuration and critical historical data
5. **Monitor the Monitor**: Alert on Prometheus health itself
6. **Security**: Protect access with authentication and network policies
7. **Documentation**: Document custom metrics and alert thresholds

## Performance Tuning

### Scrape Configuration

```yaml
# Optimize scrape intervals
global:
  scrape_interval: 30s
  evaluation_interval: 30s

# Reduce high-frequency scrapes
scrape_configs:
  - job_name: "expensive-metrics"
    scrape_interval: 60s
```

### Memory Optimization

```yaml
# Tune memory usage
extraArgs:
  - --storage.tsdb.min-block-duration=2h
  - --storage.tsdb.max-block-duration=2h
  - --web.enable-lifecycle
```

## Resources

- **Prometheus Documentation**: https://prometheus.io/docs/
- **PromQL Guide**: https://prometheus.io/docs/prometheus/latest/querying/
- **Best Practices**: https://prometheus.io/docs/practices/
- **Kubernetes Monitoring**: https://prometheus.io/docs/guides/kubernetes/
