# AlertManager

## Overview

AlertManager handles alerts sent by client applications such as Prometheus. It takes care of deduplicating, grouping, and routing alerts to the correct receiver integrations such as email, PagerDuty, Slack, or webhooks. It also handles silencing and inhibition of alerts.

## Features

- **Alert Routing**: Route alerts to different receivers based on labels
- **Grouping**: Group related alerts to reduce notification spam
- **Silencing**: Temporarily suppress alerts during maintenance
- **Inhibition**: Suppress alerts when other related alerts are firing
- **High Availability**: Multi-replica deployment with clustering
- **Web UI**: Manage alerts, silences, and configuration via web interface

## Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ Prometheus  │───▶│AlertManager │───▶│   Slack     │
│  (Alerts)   │    │ (Routing)   │    │ (Notifications)│
└─────────────┘    └─────────────┘    └─────────────┘
                           │
                           ▼
                   ┌─────────────┐
                   │  Silences   │
                   │ (Temporary) │
                   └─────────────┘
```

## Configuration

### Deployment Details

- **Namespace**: `monitoring`
- **Access URL**: https://alertmanager.home.cwbtech.net
- **Replicas**: 3 (High Availability)
- **Storage**: NFS persistent volume (5GB per replica)
- **Clustering**: Enabled for HA

### High Availability Setup

```yaml
replicaCount: 3
clustering:
  enabled: true
  # Automatic peer discovery within cluster
```

### Storage Configuration

```yaml
persistence:
  enabled: true
  storageClass: "nfs-holocron-general"
  accessMode: ReadWriteOnce
  size: 5Gi
```

### Resource Allocation

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 300m
    memory: 256Mi
```

## Alert Routing

### Routing Tree

AlertManager uses a tree-based routing configuration:

```yaml
route:
  receiver: "default"
  group_by: ["alertname", "cluster", "service"]
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  routes:
    # Critical alerts - immediate notification
    - matchers:
        - severity="critical"
      receiver: "critical"
      group_wait: 10s
      repeat_interval: 1h
      continue: true

    # Warning alerts - grouped notifications
    - matchers:
        - severity="warning"
      receiver: "warning"
      group_wait: 2m
      repeat_interval: 12h

    # Infrastructure alerts
    - matchers:
        - alertname=~"Node.*|Disk.*|Memory.*|CPU.*"
      receiver: "infrastructure"
      group_by: ["alertname", "instance"]

    # Application alerts
    - matchers:
        - alertname=~"Pod.*|Container.*|Service.*"
      receiver: "application"
      group_by: ["alertname", "namespace"]
```

### Notification Channels

#### Slack Integration

Pre-configured Slack channels for different alert types:

- **#home-critical**: Critical infrastructure alerts
- **#home-alerts**: General alerts and warnings
- **#home-infrastructure**: Infrastructure-specific alerts
- **#home-applications**: Application and service alerts

#### Channel Configuration

```yaml
receivers:
  - name: "critical"
    slack_configs:
      - api_url_file: "/etc/alertmanager/secrets/slack-webhook-url"
        channel: "#home-critical"
        title: "🚨 CRITICAL Alert"
        text: "{{ range .Alerts }}{{ .Annotations.description }}{{ end }}"
        color: "danger"
        send_resolved: true

  - name: "warning"
    slack_configs:
      - api_url_file: "/etc/alertmanager/secrets/slack-webhook-url"
        channel: "#home-alerts"
        title: "⚠️ Warning Alert"
        color: "warning"
        send_resolved: true
```

## Alert Types

### Infrastructure Alerts

#### Node-Level Alerts

- **NodeDown**: Node becomes unavailable
- **NodeHighCPU**: CPU usage > 80% for 10 minutes
- **NodeHighMemory**: Memory usage > 85% for 10 minutes
- **NodeDiskSpaceLow**: Disk usage > 85%
- **NodeDiskSpaceCritical**: Disk usage > 95%

#### Cluster-Level Alerts

- **KubernetesAPIDown**: Kubernetes API server unavailable
- **TooManyPods**: Pod count approaching node limits
- **PersistentVolumeUsageHigh**: PVC usage > 85%

### Application Alerts

#### Pod-Level Alerts

- **PodCrashLooping**: Pod restart count increasing rapidly
- **PodNotReady**: Pod not ready for > 15 minutes
- **ContainerRestarting**: Container restart rate high

#### Service-Level Alerts

- **ServiceDown**: Service endpoints unavailable
- **HighErrorRate**: HTTP 5xx error rate > 5%
- **HighLatency**: 95th percentile response time > 2 seconds

### FluxCD Alerts

#### GitOps Health

- **FluxReconciliationFailure**: Kustomization or HelmRelease failing
- **FluxSuspendedResources**: Resources suspended for > 30 minutes
- **FluxGitRepositoryFailure**: Git repository sync failures

### Istio Alerts

#### Service Mesh Health

- **IstioHighErrorRate**: Service mesh 5xx rate > 5%
- **IstioGatewayDown**: Ingress gateway unavailable
- **IstioCertificateExpiring**: Gateway certificates expiring < 7 days

## Usage

### Accessing AlertManager

Navigate to https://alertmanager.home.cwbtech.net to access the web interface.

**Main Features:**

- **Alerts**: View active, pending, and resolved alerts
- **Silences**: Create and manage alert silences
- **Status**: Check configuration and cluster status
- **Config**: View current routing configuration

### Managing Silences

#### Creating Silences

1. **Via Web UI**:

   - Navigate to "Silences" tab
   - Click "New Silence"
   - Define matchers and duration
   - Add comment explaining reason

2. **Via API**:
   ```bash
   curl -X POST https://alertmanager.home.cwbtech.net/api/v1/silences \
     -H 'Content-Type: application/json' \
     -d '{
       "matchers": [
         {"name": "alertname", "value": "NodeDown"},
         {"name": "instance", "value": "node1"}
       ],
       "startsAt": "2024-01-01T00:00:00Z",
       "endsAt": "2024-01-01T02:00:00Z",
       "comment": "Planned maintenance"
     }'
   ```

#### Common Silence Patterns

```yaml
# Silence all alerts from a specific node
matchers:
  - name: "instance"
    value: "node1"

# Silence specific alert type
matchers:
  - name: "alertname"
    value: "NodeHighCPU"

# Silence by severity level
matchers:
  - name: "severity"
    value: "warning"

# Silence namespace alerts
matchers:
  - name: "namespace"
    value: "development"
```

### Alert States

- **Inactive**: Alert condition is false
- **Pending**: Alert condition is true but within `for` duration
- **Firing**: Alert condition has been true longer than `for` duration
- **Resolved**: Alert condition returned to false

## Integration

### Prometheus Integration

AlertManager automatically receives alerts from Prometheus:

```yaml
# Prometheus configuration
rule_files:
  - "alert_rules.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - alertmanager.monitoring.svc.cluster.local:9093
```

### Grafana Integration

View AlertManager status in Grafana dashboards:

- **Alert Overview**: Active alerts by severity
- **Notification Status**: Success/failure rates
- **Silence Management**: Active silences
- **Alert History**: Firing and resolution trends

## Management

### Status Checks

```bash
# Check AlertManager pods
kubectl get pods -n monitoring -l app.kubernetes.io/name=alertmanager

# Check service and ingress
kubectl get svc -n monitoring alertmanager
kubectl get virtualservice -n monitoring alertmanager

# Verify clustering
kubectl logs -n monitoring -l app.kubernetes.io/name=alertmanager | grep cluster
```

### Configuration Management

```bash
# Check configuration
curl -k https://alertmanager.home.cwbtech.net/api/v1/status

# Reload configuration
curl -X POST https://alertmanager.home.cwbtech.net/-/reload

# Validate configuration
kubectl exec -n monitoring alertmanager-0 -- amtool config show
```

### Health Monitoring

```bash
# Health check
curl -k https://alertmanager.home.cwbtech.net/-/healthy

# Ready check
curl -k https://alertmanager.home.cwbtech.net/-/ready

# Check cluster status
curl -k https://alertmanager.home.cwbtech.net/api/v1/status | jq '.data.cluster'
```

## Troubleshooting

### Common Issues

#### Alerts Not Being Sent

```bash
# Check AlertManager logs
kubectl logs -n monitoring -l app.kubernetes.io/name=alertmanager

# Verify Slack webhook
kubectl get secret -n monitoring alertmanager-secrets -o yaml

# Test notification manually
curl -X POST https://alertmanager.home.cwbtech.net/api/v1/alerts \
  -H 'Content-Type: application/json' \
  -d '[{
    "labels": {
      "alertname": "TestAlert",
      "severity": "warning"
    },
    "annotations": {
      "summary": "Test alert"
    }
  }]'
```

#### High Memory Usage

```bash
# Check memory consumption
kubectl top pod -n monitoring -l app.kubernetes.io/name=alertmanager

# Review alert retention settings
kubectl exec -n monitoring alertmanager-0 -- amtool config show | grep retention
```

#### Clustering Issues

```bash
# Check cluster member status
kubectl exec -n monitoring alertmanager-0 -- amtool cluster show

# Verify peer discovery
kubectl logs -n monitoring alertmanager-0 | grep "cluster.*peer"
```

#### Silence Not Working

```bash
# List active silences
curl -k https://alertmanager.home.cwbtech.net/api/v1/silences

# Check silence matching
kubectl exec -n monitoring alertmanager-0 -- amtool silence query
```

### Configuration Validation

```bash
# Validate configuration syntax
kubectl exec -n monitoring alertmanager-0 -- amtool config check /etc/alertmanager/alertmanager.yml

# Test routing rules
kubectl exec -n monitoring alertmanager-0 -- amtool config routes test \
  --config.file=/etc/alertmanager/alertmanager.yml \
  severity=critical alertname=NodeDown
```

## API Usage

### Alert Management API

```bash
# Get active alerts
curl -k https://alertmanager.home.cwbtech.net/api/v1/alerts

# Post new alert
curl -X POST https://alertmanager.home.cwbtech.net/api/v1/alerts \
  -H 'Content-Type: application/json' \
  -d '[{
    "labels": {
      "alertname": "MyAlert",
      "severity": "warning",
      "instance": "localhost"
    },
    "annotations": {
      "summary": "Something went wrong"
    },
    "startsAt": "2024-01-01T00:00:00Z"
  }]'
```

### Silence Management API

```bash
# List silences
curl -k https://alertmanager.home.cwbtech.net/api/v1/silences

# Create silence
curl -X POST https://alertmanager.home.cwbtech.net/api/v1/silences \
  -H 'Content-Type: application/json' \
  -d '{
    "matchers": [
      {"name": "alertname", "value": "NodeDown"}
    ],
    "startsAt": "2024-01-01T00:00:00Z",
    "endsAt": "2024-01-01T02:00:00Z",
    "comment": "Maintenance window"
  }'

# Delete silence
curl -X DELETE https://alertmanager.home.cwbtech.net/api/v1/silence/$SILENCE_ID
```

## Security

### Access Control

- **Istio VirtualService**: Controls external access with TLS
- **Network Policies**: Restricts internal communication
- **Service Account**: Limited RBAC permissions

### Data Protection

- **HTTPS Only**: All external access via TLS
- **Secret Management**: Webhook URLs stored as sealed secrets
- **Audit Logging**: Track alert and silence activities

## Customization

### Custom Notification Channels

#### Email Notifications

```yaml
receivers:
  - name: "email-ops"
    email_configs:
      - to: "ops@company.com"
        from: "alerts@company.com"
        smarthost: "smtp.company.com:587"
        subject: "Alert: {{ .GroupLabels.alertname }}"
        body: |
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          {{ end }}
```

#### Webhook Integration

```yaml
receivers:
  - name: "webhook"
    webhook_configs:
      - url: "https://hooks.company.com/alerts"
        http_config:
          basic_auth:
            username: "alertmanager"
            password: "secret"
```

### Custom Templates

```yaml
templates:
  - "/etc/alertmanager/templates/*.tmpl"

receivers:
  - name: "custom-slack"
    slack_configs:
      - api_url_file: "/etc/alertmanager/secrets/slack-webhook-url"
        channel: "#alerts"
        title: '{{ template "slack.title" . }}'
        text: '{{ template "slack.text" . }}'
```

## Best Practices

### Alert Design

1. **Alert on Symptoms**: Alert on user-visible problems, not causes
2. **Actionable Alerts**: Each alert should have clear remediation steps
3. **Appropriate Severity**: Use severity levels consistently
4. **Avoid Alert Fatigue**: Don't over-alert on minor issues

### Routing Strategy

1. **Escalation Paths**: Route critical alerts to immediate channels
2. **Time-based Routing**: Different handling for business hours vs. off-hours
3. **Team-based Routing**: Route alerts to responsible teams
4. **Context Preservation**: Include relevant labels and annotations

### Maintenance Practices

1. **Regular Review**: Periodically review and tune alert rules
2. **Silence Management**: Use silences for planned maintenance
3. **Template Updates**: Keep notification templates current
4. **Performance Monitoring**: Monitor AlertManager performance

## Backup and Recovery

### Configuration Backup

All configuration is managed via GitOps and stored in git.

### Data Backup

```bash
# Backup AlertManager data
kubectl exec -n monitoring alertmanager-0 -- tar czf /tmp/alertmanager-$(date +%Y%m%d).tar.gz /alertmanager

# Copy backup
kubectl cp monitoring/alertmanager-0:/tmp/alertmanager-$(date +%Y%m%d).tar.gz ./alertmanager-backup.tar.gz
```

### Disaster Recovery

In case of complete failure:

1. **Redeploy via GitOps**: FluxCD will recreate all resources
2. **Restore Silences**: Silences will need to be recreated manually
3. **Verify Integration**: Test notification channels after recovery

## Resources

- **AlertManager Documentation**: https://prometheus.io/docs/alerting/latest/alertmanager/
- **Configuration Reference**: https://prometheus.io/docs/alerting/latest/configuration/
- **API Documentation**: https://github.com/prometheus/alertmanager/blob/main/api/v2/openapi.yaml
- **Best Practices**: https://prometheus.io/docs/practices/alerting/
