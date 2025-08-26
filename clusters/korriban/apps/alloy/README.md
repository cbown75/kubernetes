# Alloy (K8s Monitoring)

## Overview

Grafana Alloy (formerly Grafana Agent) is a vendor-neutral, batteries-included telemetry collector with the primary goal of making it easier to collect, transform, and send data to observability backends. In this deployment, it serves as the unified collection agent for metrics, logs, and traces from your Kubernetes cluster.

## Features

- **Unified Collection**: Single agent for metrics, logs, and traces
- **Kubernetes Native**: Built-in service discovery and auto-configuration
- **Resource Efficient**: Optimized for minimal resource usage
- **High Availability**: Clustered deployment for reliability
- **Flexible Routing**: Send data to multiple destinations
- **Rich Ecosystem**: Compatible with Prometheus, Loki, and other backends

## Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ Kubernetes  │───▶│    Alloy    │───▶│ Prometheus  │
│   Nodes     │    │ (Collector) │    │  (Metrics)  │
└─────────────┘    └─────────────┘    └─────────────┘
       │                   │                   │
       ▼                   ▼                   ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Pod Logs   │───▶│    Alloy    │───▶│    Loki     │
│(Containers) │    │   (Logs)    │    │   (Logs)    │
└─────────────┘    └─────────────┘    └─────────────┘
```

## Components

### Alloy Metrics (StatefulSet)

- **Purpose**: Collect and forward Kubernetes metrics
- **Deployment**: 2-replica StatefulSet for HA
- **Targets**: Node metrics, pod metrics, cluster state
- **Destination**: Local Prometheus instance

#### Configuration

```yaml
replicas: 2
clustering:
  enabled: true
resources:
  requests:
    cpu: 200m
    memory: 512Mi
  limits:
    cpu: 1000m
    memory: 2Gi
```

### Alloy Logs (DaemonSet)

- **Purpose**: Collect and forward container logs
- **Deployment**: DaemonSet on every node
- **Sources**: Pod logs, system logs
- **Destination**: Local Loki instance

#### Configuration

```yaml
controller:
  type: daemonset
tolerations:
  - operator: Exists # Run on all nodes including masters
```

### Alloy Singleton

- **Purpose**: Cluster-wide metrics collection
- **Deployment**: Single replica deployment
- **Targets**: Cluster-level metrics, API server
- **Destination**: Local Prometheus instance

## Data Collection

### Metrics Collection

#### Node Metrics

- **CPU Usage**: Per-core and aggregate utilization
- **Memory Usage**: Available, used, cached, buffered
- **Disk I/O**: Read/write operations and throughput
- **Network I/O**: Interface statistics and errors
- **Filesystem**: Mount point usage and availability

#### Pod Metrics

- **Container Resources**: CPU, memory, disk usage per container
- **Pod Status**: Phase, conditions, restart counts
- **Quality of Service**: Resource requests vs. limits
- **Network**: Pod-level network statistics

#### Kubernetes Metrics

- **API Server**: Request rates, latencies, errors
- **Scheduler**: Scheduling attempts and latencies
- **Controller Manager**: Work queue depths and processing times
- **Cluster State**: Node count, pod count, resource quotas

#### Infrastructure Metrics

- **Istio**: Service mesh control and data plane metrics
- **FluxCD**: Reconciliation status and performance
- **Cert Manager**: Certificate lifecycle metrics
- **MetalLB**: Load balancer pool and assignment metrics

### Logs Collection

#### Container Logs

- **Application Logs**: stdout/stderr from all containers
- **System Logs**: Infrastructure component logs
- **Audit Logs**: Kubernetes API audit trail (if enabled)

#### Log Processing

- **CRI Parsing**: Automatic parsing of container runtime logs
- **Kubernetes Metadata**: Automatic labeling with pod/namespace/container info
- **Multi-line Support**: Handling of stack traces and multi-line logs
- **Rate Limiting**: Protection against log flooding

## Configuration

### Cluster Configuration

```yaml
cluster:
  name: korriban
  platform: "" # Auto-detected
```

### Data Destinations

```yaml
destinations:
  - name: prometheus-external
    type: prometheus
    url: "http://prometheus.monitoring.svc.cluster.local:9090/api/v1/write"

  - name: loki-external
    type: loki
    url: "http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push"
```

### Enabled Features

```yaml
# Metrics collection
clusterMetrics: enable
```
