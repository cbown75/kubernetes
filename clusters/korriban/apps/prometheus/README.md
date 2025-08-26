# Prometheus Server

## Overview

Prometheus is a time-series database and monitoring system that collects metrics from configured targets at given intervals, evaluates rule expressions, displays results, and can trigger alerts when specified conditions are observed.

## Features

- **Time-Series Database**: Efficient storage and querying of metrics data
- **Service Discovery**: Automatic discovery of Kubernetes services and pods
- **PromQL**: Powerful query language for exploring metrics
- **Alert Rules**: Define conditions that trigger alerts to AlertManager
- **Web UI**: Built-in expression browser and graph visualization
- **Remote Storage**: Support for long-term storage backends

## Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Targets   │───▶│ Prometheus  │───▶│   Grafana   │
│ (Exporters) │    │  (Server)   │    │(Dashboards) │
└─────────────┘    └─────────────┘    └─────────────┘
                           │
                           ▼
                   ┌─────────────┐
                   │AlertManager │
                   │  (Alerts)   │
                   └─────────────┘
```

## Configuration

### Server Configuration

- **Namespace**: `monitoring`
- **Access URL**: https://prometheus.home.cwbtech.net
- **Storage**: NFS persistent volume (50GB)
- **Retention**: 15 days
- **Scrape Interval**: 30 seconds

### Data Persistence

```yaml
persistence:
  enabled: true
  storageClass: nfs-holocron-general
  size: 50Gi
  accessMode: ReadWriteOnce
```

### Resource Allocation

```yaml
resources:
  limits:
    cpu: 2000m
    memory: 4Gi
  requests:
    cpu: 1000m
    memory: 2Gi
```

## Service Discovery

Prometheus automatically discovers and monitors:

### Kubernetes Components

- **API Server**: Kubernetes control plane metrics
- **Kubelet**: Node and container metrics
- **Node Exporter**: System-level metrics via Alloy
- **cAdvisor**: Container resource usage

### Infrastructure Services

- **Istio**: Service mesh metrics (control plane and data plane)
- **MetalLB**: Load balancer controller metrics
- **Cert Manager**: Certificate management metrics
- **FluxCD**: GitOps controller metrics
- **Sealed Secrets**: Secret management metrics

### Application Services

- **Grafana**: Dashboard application metrics
- **Loki**: Log aggregation metrics
- **AlertManager**: Alert routing metrics
- **Alloy**: Telemetry collector metrics

## Key Metrics

### Cluster Health

```promql
# Node availability
up{job="kubernetes-nodes"}

# Pod restarts
rate(kube_pod_container_status_restarts_total[5m])

# Cluster resource usage
cluster:node_cpu_utilisation:ratio
cluster:node_memory_utilisation:ratio
```

### Application Performance

```promql
# HTTP request rate
rate(http_requests_total[5m])

# Request latency
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Error rate
rate(http_requests_total{status=~"5.."}[5m])
```

### Infrastructure Metrics

```promql
# FluxCD reconciliation status
gotk_reconcile_condition{type="Ready"}

# Certificate expiration
cert_manager_certificate_expiration_timestamp_seconds

# Istio success rate
rate(istio_requests_total{response_code!~"5.."}[5m]) / rate(istio_requests_total[5m])
```

## Usage

### Accessing Prometheus

Navigate to https://prometheus.home.cwbtech.net to access the web interface.

**Main Features:**

- **Graph**: Query metrics and create visualizations
- **Alerts**: View active and pending alerts
- **Status**: Check configuration and service discovery
- **Targets**: Monitor scrape target health

### Writing Queries

#### Basic Queries

```promql
# Current CPU usage by pod
100 * rate(container_cpu_usage_seconds_total{pod!=""}[5m])

# Memory usage by namespace
sum(container_memory_working_set_bytes{pod!=""}) by (namespace)

# Disk usage by node
node_filesystem_avail_bytes{mountpoint="/"}
```

#### Aggregation Functions

```promql
# Average CPU across all nodes
avg(node_cpu_seconds_total{mode="idle"})

# Sum of memory by namespace
sum by (namespace) (container_memory_working_set_bytes)

# Maximum response time
max(http_request_duration_seconds)
```

#### Time-based Analysis

```promql
# CPU usage over last 5 minutes
rate(node_cpu_seconds_total{mode="user"}[5m])

# Memory growth over 1 hour
increase(container_memory_working_set_bytes[1h])

# Request rate change over 24 hours
rate(http_requests_total[5m]) offset 24h
```

## Alert Rules

Pre-configured alert rules monitor critical conditions:

### Infrastructure Alerts

- **NodeDown**: Node becomes unavailable
- **HighCPUUsage**: Node CPU > 80% for 5 minutes
- **HighMemoryUsage**: Node memory > 85% for 5 minutes
- **DiskSpaceLow**: Disk usage > 85%

### Kubernetes Alerts

- **PodCrashLooping**: Pod restart count increasing
- **DeploymentReplicasMismatch**: Deployment not at desired replica count
- **PVCStorageLow**: Persistent volume claim > 85% full

### Application Alerts

- **ServiceDown**: Service endpoints unavailable
- **HighErrorRate**: HTTP 5xx error rate > 5%
- **HighLatency**: 95th percentile latency > 2 seconds

## Management

### Status Checks

```bash
# Check Prometheus pod
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus

# Check service and external access
kubectl get svc -n monitoring prometheus-server

# Verify storage
kubectl get pvc -n monitoring -l app.kubernetes.io/name=prometheus
```

### Configuration Reload

```bash
# Reload configuration (if config changes)
kubectl exec -n monitoring deployment/prometheus-server -- killall -HUP prometheus

# Check configuration status
curl https://prometheus.home.cwbtech.net/-/ready
curl https://prometheus.home.cwbtech.net/-/healthy
```

### Data Management

```bash
# Check storage usage
kubectl exec -n monitoring prometheus-server-0 -- df -h /prometheus

# View retention settings
kubectl exec -n monitoring prometheus-server-0 -- /bin/prometheus --help | grep retention
```

## Troubleshooting

### Common Issues

#### High Memory Usage

```bash
# Check current memory usage
kubectl top pod -n monitoring prometheus-server-0

# Review memory-related settings
kubectl describe pod -n monitoring prometheus-server-0 | grep -A 5 -B 5 memory
```

**Solutions:**

- Reduce retention period
- Increase memory limits
- Reduce scrape frequency for high-cardinality metrics

#### Slow Queries

```bash
# Check query logs
kubectl logs -n monitoring deployment/prometheus-server | grep "query"

# Monitor query performance in UI
# Go to https://prometheus.home.cwbtech.net/status
```

**Solutions:**

- Use recording rules for expensive queries
- Add query timeout limits
- Optimize PromQL queries

#### Missing Targets

```bash
# Check service discovery
curl -s https://prometheus.home.cwbtech.net/api/v1/targets | jq '.data.activeTargets[] | select(.health != "up")'

# Verify ServiceMonitor resources
kubectl get servicemonitor -A
```

**Solutions:**

- Check target service availability
- Verify ServiceMonitor selector labels
- Confirm network policies allow scraping

#### Storage Issues

```bash
# Check PVC status
kubectl describe pvc -n monitoring prometheus-server

# View storage events
kubectl get events -n monitoring --field-selector involvedObject.name=prometheus-server
```

**Solutions:**

- Verify NFS storage is available
- Check storage class configuration
- Ensure sufficient disk space

## Performance Optimization

### Query Optimization

```promql
# Bad: High cardinality aggregation
sum(http_requests_total) by (path, method, status, user_id)

# Good: Reduced cardinality
sum(rate(http_requests_total[5m])) by (service, status_class)
```

### Recording Rules

Create recording rules for frequently used queries:

```yaml
# Example recording rule
groups:
  - name: instance
    interval: 30s
    rules:
      - record: instance:node_cpu_utilisation:rate1m
        expr: 1 - avg(rate(node_cpu_seconds_total{mode="idle"}[1m])) by (instance)
```

### Storage Tuning

```yaml
# Optimize for your use case
retention: "15d"
retentionSize: "45GB" # Leave 10% buffer
```

## Integration

### Grafana Integration

Prometheus is automatically configured as a data source in Grafana:

```yaml
# Data source configuration
url: http://prometheus-server.monitoring.svc.cluster.local:9090
access: proxy
isDefault: true
```

### AlertManager Integration

Alerts are automatically forwarded to AlertManager:

```yaml
# Alert configuration
alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - alertmanager.monitoring.svc.cluster.local:9093
```

### Remote Storage

Configure remote write for long-term storage:

```yaml
remote_write:
  - url: "https://remote-storage.example.com/receive"
    queue_config:
      max_samples_per_send: 1000
      batch_send_deadline: 5s
```

## API Usage

### Querying API

```bash
# Instant query
curl 'https://prometheus.home.cwbtech.net/api/v1/query?query=up'

# Range query
curl 'https://prometheus.home.cwbtech.net/api/v1/query_range?query=up&start=2024-01-01T00:00:00Z&end=2024-01-01T01:00:00Z&step=15s'

# Get series metadata
curl 'https://prometheus.home.cwbtech.net/api/v1/series?match[]=up'
```

### Administrative API

```bash
# Health check
curl 'https://prometheus.home.cwbtech.net/-/healthy'

# Ready check
curl 'https://prometheus.home.cwbtech.net/-/ready'

# Configuration
curl 'https://prometheus.home.cwbtech.net/api/v1/status/config'
```

## Security

### Access Control

Access is controlled through:

- **Istio VirtualService**: Controls external access
- **Network Policies**: Restricts internal traffic
- **RBAC**: Service account permissions for service discovery

### Data Protection

- **TLS**: All external access via HTTPS
- **Authentication**: Integrated with Grafana for user management
- **Network Isolation**: Pod-to-pod communication restrictions

## Backup and Recovery

### Configuration Backup

All configuration is managed via GitOps and stored in the repository.

### Data Backup

```bash
# Create data snapshot
kubectl exec -n monitoring prometheus-server-0 -- tar czf /tmp/prometheus-$(date +%Y%m%d).tar.gz /prometheus

# Copy backup
kubectl cp monitoring/prometheus-server-0:/tmp/prometheus-$(date +%Y%m%d).tar.gz ./prometheus-backup.tar.gz
```

### Recovery

```bash
# Restore from backup (if needed)
kubectl exec -n monitoring prometheus-server-0 -- rm -rf /prometheus/*
kubectl cp ./prometheus-backup.tar.gz monitoring/prometheus-server-0:/tmp/
kubectl exec -n monitoring prometheus-server-0 -- tar xzf /tmp/prometheus-backup.tar.gz -C /
kubectl delete pod -n monitoring prometheus-server-0  # Force restart
```

## Resources

- **Prometheus Documentation**: https://prometheus.io/docs/
- **PromQL Guide**: https://prometheus.io/docs/prometheus/latest/querying/basics/
- **Recording Rules**: https://prometheus.io/docs/prometheus/latest/configuration/recording_rules/
- **Alerting Rules**: https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/
