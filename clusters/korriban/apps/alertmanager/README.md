# AlertManager for Korriban Cluster

## Overview

AlertManager deployment using the official `prometheus-community/alertmanager` Helm chart. This provides a production-ready alerting solution integrated with the existing monitoring stack.

## Features

- **High Availability**: 3 replicas with clustering
- **NFS Storage**: 5Gi storage using `nfs-holocron-general`
- **Traefik Integration**: HTTPS access without basic auth
- **Slack Integration**: Primary notification channel with rich formatting
- **Prometheus Integration**: ServiceMonitor for metrics collection
- **Smart Routing**: Alert routing based on severity and type

## Slack Integration

AlertManager is configured to send notifications to different Slack channels based on alert type:

### **Channels:**

- `#home-critical` - Critical alerts with @channel notifications
- `#home-alerts` - General alerts and warnings
- `#home-infrastructure` - Node, disk, memory alerts
- `#home-applications` - Pod, container, service alerts

### **Message Format:**

- **Rich formatting** with emojis and structured text
- **Alert details** including severity, instance, summary
- **Resolved notifications** when alerts clear
- **@channel tags** for critical alerts

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Prometheus    │────│   AlertManager   │────│   Webhooks      │
│   (alerts)      │    │   3 replicas     │    │   (receivers)   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Access

- **URL**: https://alertmanager.home.cwbtech.net
- **No Authentication**: Direct access via Traefik
- **TLS**: Automatic Let's Encrypt certificate

## Configuration

### Storage

- **Storage Class**: `nfs-holocron-general`
- **Size**: 5Gi per replica
- **Access Mode**: ReadWriteOnce

### Clustering

- **Replicas**: 3 for high availability
- **Communication**: Port 9094 (gossip protocol)
- **Anti-affinity**: Spread across different nodes

### Alert Routing

#### Routes

1. **Critical Alerts**: 10s wait, 1h repeat
2. **Warning Alerts**: 2m wait, 12h repeat
3. **Infrastructure**: Node/disk/memory alerts
4. **Application**: Pod/container/service alerts

#### Receivers

- `default`: Basic webhook receiver
- `critical`: High priority alerts
- `warning`: Standard warnings
- `infrastructure`: System-level alerts
- `application`: Application-level alerts

## Prometheus Rules

The deployment includes comprehensive alerting rules:

### AlertManager Health

- AlertManager down
- Configuration reload failures
- Notification failures
- Cluster health

### Infrastructure Monitoring

- Node down
- High CPU/memory usage
- Disk space warnings/critical

### Kubernetes Monitoring

- Pod crash looping
- Pod not ready
- Deployment/StatefulSet replica mismatches

### Storage Monitoring

- PVC usage high/critical

### FluxCD Monitoring

- Reconciliation failures
- Suspended resources

## Secret Management

### Required Sealed Secrets

Before deploying, you need to create the Slack webhook URL secret (required):

```bash
# Get your Slack webhook URL from:
# 1. Go to https://api.slack.com/apps
# 2. Create new app or select existing app
# 3. Go to "Incoming Webhooks"
# 4. Create webhook for your workspace
# 5. Copy the webhook URL (https://hooks.slack.com/services/...)

# Run the script to create sealed secrets
./scripts/create-alertmanager-secrets.sh
```

### Slack Channels Setup

Create these channels in your Slack workspace:

- `#home-critical` - For critical alerts (will receive @channel notifications)
- `#home-alerts` - For general alerts and warnings
- `#home-infrastructure` - For infrastructure-related alerts
- `#home-applications` - For application/pod alerts

**Note:** The AlertManager bot should be invited to all these channels.

## Deployment

The AlertManager is deployed via FluxCD HelmRelease:

```bash
# Check deployment status
kubectl get helmrelease -n monitoring alertmanager

# Check pods
kubectl get pods -n monitoring -l app.kubernetes.io/name=alertmanager

# Check cluster status
kubectl port-forward -n monitoring svc/alertmanager 9093:9093
curl -s http://localhost:9093/api/v2/status | jq '.cluster'
```

## Configuration Updates

To update AlertManager configuration:

1. Edit the `config` section in `release.yaml`
2. Commit to git
3. FluxCD will automatically apply changes

Example - adding email notifications:

```yaml
receivers:
  - name: "critical"
    email_configs:
      - to: "admin@cwbtech.net"
        subject: "[CRITICAL] {{ .GroupLabels.alertname }}"
        body: |
          {{ range .Alerts.Firing }}
          Alert: {{ .Labels.alertname }}
          Instance: {{ .Labels.instance }}
          Summary: {{ .Annotations.summary }}
          {{ end }}
    webhook_configs:
      - url: "http://webhook-receiver.monitoring.svc.cluster.local:8080/critical"
```

## Monitoring AlertManager

### Key Metrics

- `alertmanager_notifications_total`: Total notifications sent
- `alertmanager_notifications_failed_total`: Failed notifications
- `alertmanager_cluster_members`: Cluster member count
- `alertmanager_config_last_reload_successful`: Config status

### Health Checks

```bash
# Check AlertManager health
kubectl get pods -n monitoring -l app.kubernetes.io/name=alertmanager

# View alerts
kubectl port-forward -n monitoring svc/alertmanager 9093:9093
curl -s http://localhost:9093/api/v2/alerts

# Check cluster status
curl -s http://localhost:9093/api/v2/status | jq '.cluster'
```

## Troubleshooting

### Common Issues

#### Pods Not Starting

```bash
# Check pod status
kubectl describe pod -n monitoring -l app.kubernetes.io/name=alertmanager

# Check logs
kubectl logs -n monitoring -l app.kubernetes.io/name=alertmanager
```

#### Storage Issues

```bash
# Check PVC status
kubectl get pvc -n monitoring

# Check storage class
kubectl get sc nfs-holocron-general

# Check NFS connectivity
kubectl exec -n monitoring alertmanager-0 -- df -h /alertmanager
```

#### Clustering Issues

```bash
# Check if all instances see each other
kubectl port-forward -n monitoring alertmanager-0 9093:9093
curl -s http://localhost:9093/api/v2/status | jq '.cluster.peers'

# Should show 3 members total
```

#### Configuration Issues

```bash
# Validate configuration
kubectl logs -n monitoring -l app.kubernetes.io/name=alertmanager | grep -i error

# Check configuration reload
kubectl logs -n monitoring -l app.kubernetes.io/name=alertmanager | grep -i reload
```

### Testing Alerts

Create a test alert to verify the pipeline:

```bash
# Create test PrometheusRule
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: test-alert
  namespace: monitoring
spec:
  groups:
  - name: test
    rules:
    - alert: TestAlert
      expr: vector(1)
      labels:
        severity: warning
      annotations:
        summary: "Test alert"
        description: "This is a test alert"
EOF

# Check alert in Prometheus
# Visit: https://prometheus.home.cwbtech.net/alerts

# Check alert in AlertManager
# Visit: https://alertmanager.home.cwbtech.net/#/alerts

# Clean up
kubectl delete prometheusrule test-alert -n monitoring
```

## Integration with Prometheus

Ensure Prometheus is configured to send alerts to AlertManager:

```yaml
# Already configured in your Prometheus setup
alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - alertmanager:9093
```

The ServiceMonitor automatically configures Prometheus to scrape AlertManager metrics.

## Next Steps

1. **Configure Email/Slack**: Add real notification channels
2. **Tune Alert Rules**: Adjust thresholds based on your environment
3. **Add Custom Receivers**: Create application-specific notification channels
4. **Set up Webhooks**: Integrate with external systems (PagerDuty, etc.)
5. **Create Dashboards**: Build Grafana dashboards for AlertManager metrics
