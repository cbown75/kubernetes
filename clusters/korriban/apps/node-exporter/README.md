# Node Exporter for Korriban Cluster

## Overview

Node Exporter deployment using the official `prometheus-community/prometheus-node-exporter` Helm chart. This provides host-level metrics collection for the monitoring stack.

## Features

- **DaemonSet Deployment**: Runs on every node including control plane
- **Security Hardened**: Proper security contexts where possible
- **ServiceMonitor Support**: Automatic Prometheus discovery
- **Optimized Configuration**: Excludes unnecessary collectors
- **Resource Management**: Conservative CPU and memory limits

## Chart Information

- **Chart**: `prometheus-community/prometheus-node-exporter`
- **Version**: `4.47.x` (latest 4.47.x)
- **App Version**: `v1.9.1`
- **Repository**: https://prometheus-community.github.io/helm-charts

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ Node Exporter   │────│   ServiceMonitor │────│   Prometheus    │
│ (DaemonSet)     │    │   (Discovery)    │    │   (Scraping)    │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Security Requirements

Node Exporter requires privileged access for complete metrics:

- **hostNetwork: true** - Access to host network
- **hostPID: true** - Access to host processes
- **runAsUser: 0** - Root access for device metrics
- **Host path mounts** - `/proc`, `/sys`, `/` access

These requirements are necessary for comprehensive system monitoring.

## Key Metrics Collected

- **CPU**: `node_cpu_seconds_total`
- **Memory**: `node_memory_*`
- **Disk**: `node_filesystem_*`, `node_disk_*`
- **Network**: `node_network_*`
- **Load Average**: `node_load1`, `node_load5`, `node_load15`
- **Boot Time**: `node_boot_time_seconds`

## Integration with Existing Stack

This deployment integrates seamlessly with your monitoring components:

### Prometheus Integration

ServiceMonitor automatically configures scraping:

- **Job**: `node-exporter`
- **Interval**: 30 seconds
- **Labels**: `release: prometheus`

### AlertManager Integration

Enables your existing alert rules:

- ✅ **NodeDown** - `up{job="node-exporter"} == 0`
- ✅ **HighCPUUsage** - CPU usage alerts
- ✅ **HighMemoryUsage** - Memory usage alerts
- ✅ **DiskSpaceLow** - Disk space alerts
- ✅ **DiskSpaceCritical** - Critical disk alerts

## Deployment

### Check Status

```bash
# Check HelmRelease
kubectl get helmrelease -n monitoring node-exporter

# Check DaemonSet
kubectl get daemonset -n monitoring node-exporter

# Check pods on all nodes
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus-node-exporter -o wide
```

### Verify Metrics

```bash
# Port forward to test metrics
kubectl port-forward -n monitoring svc/node-exporter 9100:9100

# Check metrics endpoint
curl http://localhost:9100/metrics | head -20

# Verify specific metrics
curl -s http://localhost:9100/metrics | grep -E "node_(cpu|memory|filesystem)"
```

### Prometheus Targets

Check that Prometheus is discovering Node Exporter:

```bash
# Port forward to Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Visit: http://localhost:9090/targets
# Look for: node-exporter targets with State: UP
```

## Configuration

### Resource Limits

Conservative limits for stable operation:

```yaml
resources:
  limits:
    cpu: 250m
    memory: 180Mi
  requests:
    cpu: 102m
    memory: 180Mi
```

### Collectors

Optimized collector configuration:

- ✅ **Enabled**: filesystem, cpu, memory, network, disk
- ❌ **Disabled**: wifi, hwmon (not needed in k8s)

### Filtering

Excludes unnecessary mount points:

- Container runtime mounts
- Kubernetes internal mounts
- Virtual filesystems

## Troubleshooting

### Common Issues

1. **Pods not starting**

   - Check namespace Pod Security Standards
   - Verify privileged access allowed

2. **Permission denied errors**

   - Confirm security contexts
   - Check host path mount permissions

3. **Missing metrics**

   - Verify collector arguments
   - Check volume mounts

4. **ServiceMonitor not working**
   - Confirm Prometheus discovers ServiceMonitors
   - Check label selectors

### Diagnostic Commands

```bash
# Check pod logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus-node-exporter

# Describe pod for events
kubectl describe pod -n monitoring -l app.kubernetes.io/name=prometheus-node-exporter

# Check service endpoints
kubectl get endpoints -n monitoring node-exporter

# Verify ServiceMonitor
kubectl get servicemonitor -n monitoring node-exporter -o yaml
```

## Monitoring Node Exporter

Monitor Node Exporter itself with these queries:

```promql
# Targets up
up{job="node-exporter"}

# Scrape duration
prometheus_tsdb_symbol_table_size_bytes

# Resource usage
rate(container_cpu_usage_seconds_total{pod=~"node-exporter.*"}[5m])
container_memory_working_set_bytes{pod=~"node-exporter.*"}
```

## What This Completes

With Node Exporter deployed, your monitoring stack is now complete:

- ✅ **Prometheus** - Metrics collection and storage
- ✅ **Node Exporter** - Host-level metrics
- ✅ **AlertManager** - Alert routing and notifications
- ✅ **Grafana** - Visualization and dashboards

All infrastructure alerts in your AlertManager rules will now function correctly.
