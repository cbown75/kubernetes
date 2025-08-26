# Loki

## Overview

Loki is a horizontally scalable, highly available, multi-tenant log aggregation system inspired by Prometheus. It is designed to be cost-effective and easy to operate, indexing only metadata about logs rather than the contents of the logs themselves.

## Features

- **Log Aggregation**: Centralized collection of logs from all cluster workloads
- **LogQL**: Prometheus-like query language for log exploration
- **Label-based Indexing**: Efficient storage by indexing only metadata
- **Multi-tenancy**: Support for multiple isolated tenants
- **Grafana Integration**: Native integration with Grafana for visualization
- **Retention Management**: Configurable log retention and compaction

## Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│    Alloy    │───▶│    Loki     │───▶│   Grafana   │
│ (Collector) │    │  (Storage)  │    │(Exploration)│
└─────────────┘    └─────────────┘    └─────────────┘
       │                   │
       ▼                   ▼
┌─────────────┐    ┌─────────────┐
│  Pod Logs   │    │  NFS Store  │
│ (Kubernetes)│    │(Persistent) │
└─────────────┘    └─────────────┘
```

## Configuration

### Deployment Details

- **Namespace**: `monitoring`
- **Access URL**: https://loki.home.cwbtech.net
- **Deployment Mode**: SingleBinary (suitable for small to medium clusters)
- **Storage**: NFS persistent volume (10GB)
- **Retention**: 7 days (168 hours)

### Storage Configuration

```yaml
persistence:
  enabled: true
  size: 10Gi
  storageClass: nfs-holocron-general
  accessModes:
    - ReadWriteOnce
```

### Resource Allocation

```yaml
resources:
  limits:
    cpu: 500m
    memory: 1Gi
  requests:
    cpu: 250m
    memory: 512Mi
```

### Retention Policy

```yaml
limits_config:
  retention_period: 168h # 7 days
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  max_entries_limit_per_query: 5000
```

## Log Collection

### Sources

Loki automatically receives logs from:

#### Kubernetes System Logs

- **Pod Logs**: All application container logs
- **System Pods**: kube-system namespace components
- **Infrastructure Pods**: FluxCD, cert-manager, MetalLB, Istio

#### Application Logs

- **Monitoring Stack**: Prometheus, Grafana, AlertManager
- **User Applications**: Any deployed workloads

### Log Ingestion Pipeline

1. **Collection**: Alloy DaemonSet collects logs from all nodes
2. **Processing**: CRI parser extracts Kubernetes metadata
3. **Labeling**: Automatic labels for namespace, pod, container
4. **Forwarding**: Logs sent to Loki via HTTP API
5. **Storage**: Indexed and stored in NFS filesystem

### Automatic Labels

Logs are automatically labeled with:

- **namespace**: Kubernetes namespace
- **pod**: Pod name
- **container**: Container name
- **app**: Application label (if present)
- **service**: Service name (if present)

## Query Language (LogQL)

### Basic Queries

#### Log Stream Selection

```logql
# All logs from monitoring namespace
{namespace="monitoring"}

# Logs from specific pod
{pod="prometheus-server-0"}

# Logs from all grafana containers
{app="grafana"}
```

#### Text Filtering

```logql
# Find error messages
{namespace="production"} |= "ERROR"

# Find multiple terms
{namespace="production"} |= "ERROR" or "FATAL"

# Exclude debug messages
{namespace="production"} != "DEBUG"

# Regex matching
{namespace="production"} |~ "error|ERROR|Error"
```

### Advanced Queries

#### Log Parsing

```logql
# Parse JSON logs
{app="my-app"} | json

# Parse logfmt logs
{app="my-app"} | logfmt

# Extract fields with regex
{app="my-app"} | regexp "(?P<level>\\w+) (?P<message>.*)"
```

#### Metrics from Logs

```logql
# Count log lines
count_over_time({namespace="production"}[1h])

# Error rate
rate({namespace="production"} |= "ERROR" [5m])

# Bytes per second
sum(rate({namespace="production"}[1m])) by (pod)
```

#### Aggregations

```logql
# Top error-producing pods
topk(10, sum(rate({namespace="production"} |= "ERROR" [5m])) by (pod))

# Log volume by namespace
sum(rate({namespace=~".+"}[5m])) by (namespace)

# Average log line length
avg_over_time({app="my-app"} | line_format "{{len .}}" | unwrap [5m])
```

## Common Use Cases

### Troubleshooting Applications

#### Find Errors in Specific Service

```logql
{app="my-service", namespace="production"} |= "ERROR" or "FATAL" or "Exception"
```

#### Monitor Pod Restart Reasons

```logql
{namespace="kube-system"} |= "Failed" or "FailedMount" or "CrashLoopBackOff"
```

#### Track FluxCD Reconciliation Issues

```logql
{namespace="flux-system"} |= "reconciliation failed" or "error"
```

### Performance Monitoring

#### High CPU Usage Correlation

```logql
{namespace="production"} |= "high CPU" or "performance" or "slow"
```

#### Memory Issues

```logql
{namespace=~".+"} |= "OutOfMemory" or "OOM" or "memory"
```

### Security Monitoring

#### Authentication Failures

```logql
{namespace=~".+"} |= "authentication failed" or "unauthorized" or "403"
```

#### Suspicious Activity

```logql
{namespace=~".+"} |= "attack" or "intrusion" or "malicious"
```

## Integration

### Grafana Integration

Loki is pre-configured as a data source in Grafana:

```yaml
# Data source configuration
name: Loki
type: loki
url: http://loki.monitoring.svc.cluster.local:3100
access: proxy
```

#### Explore Logs in Grafana

1. **Navigate to Explore**: Click "Explore" in Grafana sidebar
2. **Select Loki**: Choose Loki from data source dropdown
3. **Build Query**: Use LogQL to filter and search logs
4. **View Results**: Browse logs with syntax highlighting
5. **Create Alerts**: Set up log-based alerts

### Prometheus Integration

Combine logs with metrics for comprehensive monitoring:

#### Correlation Queries

```logql
# High error rate correlation
rate({app="my-app"} |= "ERROR" [5m]) and on() prometheus_metric > 0.1
```

### Alert Integration

Create alerts based on log patterns:

```yaml
# Alert rule example
- alert: HighErrorRate
  expr: rate({namespace="production"} |= "ERROR" [5m]) > 0.1
  for: 2m
  labels:
    severity: warning
  annotations:
    summary: "High error rate detected in logs"
```

## Management

### Status Checks

```bash
# Check Loki pod
kubectl get pods -n monitoring -l app.kubernetes.io/name=loki

# Check service
kubectl get svc -n monitoring loki

# Verify ingestion
kubectl get virtualservice -n monitoring loki
```

### Health Monitoring

```bash
# Health check endpoint
curl -k https://loki.home.cwbtech.net/ready

# Check metrics endpoint
curl -k https://loki.home.cwbtech.net/metrics

# View current configuration
curl -k https://loki.home.cwbtech.net/config
```

### Storage Management

```bash
# Check storage usage
kubectl exec -n monitoring deployment/loki -- du -sh /var/loki

# Check PVC status
kubectl get pvc -n monitoring -l app.kubernetes.io/name=loki

# Monitor compaction
kubectl logs -n monitoring deployment/loki | grep compactor
```

## Troubleshooting

### Common Issues

#### Logs Not Appearing

```bash
# Check Alloy log collectors
kubectl get pods -n monitoring -l app.kubernetes.io/name=alloy-logs

# Verify log forwarding
kubectl logs -n monitoring -l app.kubernetes.io/name=alloy-logs

# Check Loki ingestion logs
kubectl logs -n monitoring deployment/loki | grep -i ingest
```

**Solutions:**

- Verify Alloy configuration
- Check network policies
- Confirm Loki service endpoint

#### High Memory Usage

```bash
# Check current memory usage
kubectl top pod -n monitoring -l app.kubernetes.io/name=loki

# Review memory configuration
kubectl describe pod -n monitoring -l app.kubernetes.io/name=loki | grep memory
```

**Solutions:**

- Reduce retention period
- Increase memory limits
- Optimize query patterns

#### Query Timeouts

```bash
# Check query performance
kubectl logs -n monitoring deployment/loki | grep -i "query"

# Monitor query duration
curl -k https://loki.home.cwbtech.net/metrics | grep query_duration
```

**Solutions:**

- Reduce query time range
- Add more specific label filters
- Increase query timeout settings

#### Storage Issues

```bash
# Check storage usage
kubectl describe pvc -n monitoring -l app.kubernetes.io/name=loki

# Verify NFS connectivity
kubectl exec -n monitoring deployment/loki -- df -h /var/loki
```

**Solutions:**

- Ensure NFS storage is available
- Check storage class configuration
- Monitor retention and compaction

### Performance Optimization

#### Query Optimization

```logql
# Bad: No label filters
{} |= "ERROR"

# Good: Specific label filters
{namespace="production", app="my-service"} |= "ERROR"
```

#### Index Optimization

- **Use specific labels**: Avoid high-cardinality labels
- **Label consistency**: Maintain consistent labeling across applications
- **Time range limits**: Use appropriate time ranges for queries

## API Usage

### Query API

```bash
# Query logs
curl -G -s "https://loki.home.cwbtech.net/loki/api/v1/query" \
  --data-urlencode 'query={namespace="monitoring"}' \
  --data-urlencode 'limit=100'

# Query range
curl -G -s "https://loki.home.cwbtech.net/loki/api/v1/query_range" \
  --data-urlencode 'query={namespace="monitoring"}' \
  --data-urlencode 'start=2024-01-01T00:00:00Z' \
  --data-urlencode 'end=2024-01-01T01:00:00Z'

# Get label values
curl -G -s "https://loki.home.cwbtech.net/loki/api/v1/labels"
```

### Push API

```bash
# Push logs (used by Alloy)
curl -X POST "https://loki.home.cwbtech.net/loki/api/v1/push" \
  -H "Content-Type: application/json" \
  -d '{"streams":[{"stream":{"app":"test"},"values":[["1640995200000000000","test log message"]]}]}'
```

## Security

### Access Control

- **Istio VirtualService**: Controls external access
- **Network Policies**: Restricts pod-to-pod communication
- **RBAC**: Service account permissions

### Data Protection

- **TLS**: All external access via HTTPS
- **Multi-tenancy**: Logical separation of log data
- **Retention**: Automatic log cleanup after retention period

### Log Sanitization

Consider sanitizing sensitive information:

```yaml
# Pipeline stage to remove sensitive data
pipeline_stages:
  - regex:
      expression: "password=[^\\s]+"
      replace: "password=***"
```

## Backup and Recovery

### Configuration Backup

All configuration is managed via GitOps and stored in git.

### Data Backup

```bash
# Backup Loki data
kubectl exec -n monitoring deployment/loki -- tar czf /tmp/loki-$(date +%Y%m%d).tar.gz /var/loki

# Copy backup
kubectl cp monitoring/loki-0:/tmp/loki-$(date +%Y%m%d).tar.gz ./loki-backup.tar.gz
```

### Recovery

```bash
# Restore from backup (if needed)
kubectl exec -n monitoring deployment/loki -- rm -rf /var/loki/*
kubectl cp ./loki-backup.tar.gz monitoring/loki-0:/tmp/
kubectl exec -n monitoring deployment/loki -- tar xzf /tmp/loki-backup.tar.gz -C /
kubectl delete pod -n monitoring -l app.kubernetes.io/name=loki  # Force restart
```

## Best Practices

### Log Management

1. **Structured Logging**: Use JSON or logfmt for easier parsing
2. **Consistent Labeling**: Standardize labels across applications
3. **Appropriate Retention**: Balance storage cost with debugging needs
4. **Log Levels**: Use appropriate log levels (DEBUG, INFO, WARN, ERROR)

### Query Efficiency

1. **Use Label Filters**: Always include label filters in queries
2. **Limit Time Ranges**: Use specific time ranges for better performance
3. **Avoid Wildcards**: Minimize use of regex and wildcards
4. **Cache Results**: Leverage Grafana's query result caching

### Storage Management

1. **Monitor Usage**: Track storage consumption and growth
2. **Retention Tuning**: Adjust retention based on actual needs
3. **Compaction**: Ensure compaction is running regularly
4. **Backup Strategy**: Regular backups of critical log data

## Resources

- **Loki Documentation**: https://grafana.com/docs/loki/
- **LogQL Guide**: https://grafana.com/docs/loki/latest/logql/
- **Grafana Integration**: https://grafana.com/docs/grafana/latest/datasources/loki/
- **Best Practices**: https://grafana.com/docs/loki/latest/best-practices/
