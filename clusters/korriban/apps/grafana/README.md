# Grafana

## Overview

Grafana is an open-source analytics and interactive visualization platform that allows you to query, visualize, alert on, and understand your metrics no matter where they are stored. In this deployment, Grafana serves as the primary dashboard and visualization layer for your monitoring stack.

## Features

- **Rich Visualizations**: Graphs, tables, heatmaps, histograms, and more
- **Dashboard Management**: Organize panels into customizable dashboards
- **Multiple Data Sources**: Prometheus, Loki, and external sources
- **Alerting**: Visual alert rules with notification channels
- **User Management**: Authentication and authorization
- **Plugins**: Extensible with community and commercial plugins

## Configuration

### Deployment Details

- **Namespace**: `monitoring`
- **Access URL**: https://grafana.home.cwbtech.net
- **Storage**: NFS persistent volume (10GB)
- **Authentication**: Local admin user + basic auth middleware

### Data Sources

Pre-configured data sources include:

#### Prometheus

- **URL**: `http://prometheus-server.monitoring.svc.cluster.local:9090`
- **Type**: Time-series metrics
- **Usage**: Primary metrics source for all dashboards

#### Loki

- **URL**: `http://loki.monitoring.svc.cluster.local:3100`
- **Type**: Log aggregation
- **Usage**: Log exploration and correlation with metrics

### Storage Configuration

```yaml
persistence:
  enabled: true
  storageClassName: nfs-holocron-general
  accessModes:
    - ReadWriteOnce
  size: 10Gi
```

### Resource Allocation

```yaml
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi
```

## Access and Authentication

### Login Credentials

Default admin credentials are managed via sealed secrets:

- **Admin User**: Configured via sealed secret
- **Admin Password**: Configured via sealed secret

### External Access

Access Grafana at https://grafana.home.cwbtech.net through Istio ingress with automatic TLS termination.

### Authentication Methods

1. **Local Users**: Built-in user database
2. **Basic Auth**: HTTP basic authentication (optional)
3. **Anonymous Access**: Disabled by default

## Pre-built Dashboards

### Infrastructure Dashboards

#### Kubernetes Cluster Overview

- **Nodes**: CPU, memory, disk, network usage
- **Pods**: Resource consumption by namespace
- **Deployments**: Replica status and resource usage
- **Storage**: PVC usage across namespaces

#### Istio Service Mesh

- **Traffic Management**: Request rates, latency, error rates
- **Security**: mTLS status, certificate health
- **Performance**: Proxy resource usage, connection pools
- **Topology**: Service dependencies and communication flows

#### FluxCD GitOps

- **Reconciliation Status**: Kustomization and HelmRelease health
- **Sync Performance**: Reconciliation times and frequencies
- **Error Tracking**: Failed reconciliations and resource conflicts
- **Git Activity**: Repository polling and update frequency

### Application Dashboards

#### Monitoring Stack

- **Prometheus**: Query performance, storage usage, target health
- **Loki**: Ingestion rates, query performance, storage usage
- **AlertManager**: Alert volumes, notification success rates
- **Grafana**: User activity, dashboard usage, query performance

#### Infrastructure Services

- **Cert Manager**: Certificate lifecycle, renewal status
- **MetalLB**: IP pool usage, service allocation
- **Storage**: CSI driver performance, volume usage
- **Sealed Secrets**: Controller health, decryption status

## Dashboard Management

### Creating Dashboards

1. **Access Grafana UI**: Navigate to https://grafana.home.cwbtech.net
2. **Create Dashboard**: Click "+" → "Dashboard"
3. **Add Panels**: Choose visualization type and configure queries
4. **Save Dashboard**: Assign name, folder, and tags

### Dashboard as Code

Export dashboards as JSON and manage via ConfigMaps:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-custom-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  dashboard.json: |
    {
      "dashboard": {
        "title": "My Custom Dashboard",
        "panels": [...]
      }
    }
```

### Organizing Dashboards

- **Folders**: Group related dashboards
- **Tags**: Categorize for easy searching
- **Starred**: Mark frequently used dashboards
- **Home Dashboard**: Set default landing page

## Common Queries

### Prometheus Queries (PromQL)

#### Cluster Resources

```promql
# Node CPU usage
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Pod memory usage
sum by (pod, namespace) (container_memory_working_set_bytes{pod!=""})

# Storage usage by PVC
kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes * 100
```

#### Application Metrics

```promql
# HTTP request rate
rate(http_requests_total[5m])

# Error rate percentage
rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) * 100

# 95th percentile response time
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

#### Infrastructure Health

```promql
# FluxCD reconciliation status
gotk_reconcile_condition{type="Ready"}

# Certificate expiration days
(cert_manager_certificate_expiration_timestamp_seconds - time()) / 86400

# Istio success rate
rate(istio_requests_total{response_code!~"5.."}[5m]) / rate(istio_requests_total[5m]) * 100
```

### Loki Queries (LogQL)

#### Error Detection

```logql
# Application errors
{namespace="production"} |= "ERROR" or "FATAL" or "error"

# Failed pod events
{namespace=~".*"} |= "Failed" or "FailedMount" or "CrashLoopBackOff"

# FluxCD reconciliation failures
{namespace="flux-system"} |= "reconciliation failed"
```

#### Log Analysis

```logql
# Request logs with status codes
{app="my-app"} | json | status >= 400

# Log volume by service
sum by (service) (count_over_time({namespace="production"}[1h]))

# Error rate from logs
sum(rate({app="my-app"} |= "error" [5m])) / sum(rate({app="my-app"}[5m]))
```

## Alerting

### Alert Rules

Create visual alerts in Grafana:

1. **Navigate to Alerting** → "Alert Rules"
2. **Create Rule**: Define query and conditions
3. **Set Evaluation**: Configure frequency and duration
4. **Add Annotations**: Provide context and runbooks
5. **Configure Notifications**: Set up notification channels

### Notification Channels

Configure various notification methods:

#### Slack Integration

```yaml
# Slack webhook configuration
type: slack
url: https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK
channel: "#alerts"
title: "Grafana Alert"
```

#### Email Notifications

```yaml
# SMTP configuration
type: email
addresses: ["ops@company.com"]
subject: "Alert: {{ .GroupLabels.alertname }}"
```

### Alert States

- **OK**: Condition is false
- **Pending**: Condition is true but within evaluation period
- **Alerting**: Condition has been true for longer than evaluation period
- **No Data**: No data points received within timeout period

## Customization

### Themes and Appearance

- **Light/Dark Theme**: Toggle in user preferences
- **Organization Settings**: Customize logo, colors, and branding
- **Time Zone**: Configure display time zone per user

### Plugins

#### Useful Plugins

- **Pie Chart**: Additional visualization type
- **Worldmap Panel**: Geographic data visualization
- **Table Panel**: Enhanced table functionality
- **Stat Panel**: Single value displays

#### Installing Plugins

```yaml
# Via environment variable in deployment
env:
  - name: GF_INSTALL_PLUGINS
    value: "grafana-piechart-panel,grafana-worldmap-panel"
```

### Variables and Templating

Create dynamic dashboards with variables:

#### Query Variables

```
# Namespace variable
query: label_values(kube_pod_info, namespace)

# Node variable
query: label_values(kube_node_info, node)
```

#### Usage in Queries

```promql
# Use variables in queries
rate(container_cpu_usage_seconds_total{namespace="$namespace"}[5m])
```

## Management

### Status Checks

```bash
# Check Grafana pod
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana

# Check service and ingress
kubectl get svc -n monitoring monitoring-grafana
kubectl get virtualservice -n monitoring grafana

# Verify storage
kubectl get pvc -n monitoring -l app.kubernetes.io/name=grafana
```

### Configuration Management

```bash
# Check Grafana configuration
kubectl get configmap -n monitoring | grep grafana

# View current settings
kubectl exec -n monitoring deployment/monitoring-grafana -- cat /etc/grafana/grafana.ini
```

### Health Monitoring

```bash
# Health check endpoint
curl -k https://grafana.home.cwbtech.net/api/health

# Check data source connectivity
curl -k https://grafana.home.cwbtech.net/api/datasources/proxy/1/api/v1/query?query=up
```

## Troubleshooting

### Common Issues

#### Cannot Access Dashboard

```bash
# Check pod status
kubectl describe pod -n monitoring -l app.kubernetes.io/name=grafana

# Check logs
kubectl logs -n monitoring deployment/monitoring-grafana

# Verify Istio routing
kubectl describe virtualservice -n monitoring grafana
```

#### Data Source Connection Errors

```bash
# Test Prometheus connectivity
kubectl exec -n monitoring deployment/monitoring-grafana -- wget -O- http://prometheus-server.monitoring.svc.cluster.local:9090/api/v1/query?query=up

# Check network policies
kubectl describe networkpolicy -n monitoring
```

#### Dashboard Not Loading

```bash
# Check Grafana logs for errors
kubectl logs -n monitoring deployment/monitoring-grafana | grep -i error

# Verify dashboard ConfigMaps
kubectl get configmap -n monitoring -l grafana_dashboard=1
```

#### Authentication Issues

```bash
# Check sealed secrets
kubectl get sealedsecret -n monitoring grafana-admin-secret

# Verify secret creation
kubectl get secret -n monitoring grafana-admin-secret -o yaml
```

### Performance Issues

#### Slow Dashboard Loading

- **Reduce query complexity**: Simplify PromQL queries
- **Optimize time ranges**: Use appropriate time ranges for panels
- **Cache settings**: Adjust query caching in Grafana settings

#### High Memory Usage

```bash
# Check memory usage
kubectl top pod -n monitoring -l app.kubernetes.io/name=grafana

# Review memory settings
kubectl describe pod -n monitoring -l app.kubernetes.io/name=grafana | grep -A 5 memory
```

## Backup and Recovery

### Dashboard Backup

```bash
# Export all dashboards
kubectl get configmap -n monitoring -l grafana_dashboard=1 -o yaml > grafana-dashboards-backup.yaml

# Individual dashboard export via API
curl -k -H "Authorization: Bearer $API_TOKEN" \
  "https://grafana.home.cwbtech.net/api/dashboards/uid/$DASHBOARD_UID" > dashboard.json
```

### Data Backup

```bash
# Grafana database backup
kubectl exec -n monitoring deployment/monitoring-grafana -- tar czf /tmp/grafana-data.tar.gz /var/lib/grafana

# Copy backup locally
kubectl cp monitoring/monitoring-grafana-xxx:/tmp/grafana-data.tar.gz ./grafana-backup.tar.gz
```

### Configuration Backup

All configuration is managed via GitOps and stored in the git repository.

## API Usage

### Dashboard API

```bash
# List all dashboards
curl -k -H "Authorization: Bearer $API_TOKEN" \
  "https://grafana.home.cwbtech.net/api/search"

# Get dashboard by UID
curl -k -H "Authorization: Bearer $API_TOKEN" \
  "https://grafana.home.cwbtech.net/api/dashboards/uid/$UID"

# Create/update dashboard
curl -k -X POST -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d @dashboard.json \
  "https://grafana.home.cwbtech.net/api/dashboards/db"
```

### User Management API

```bash
# List users
curl -k -H "Authorization: Bearer $API_TOKEN" \
  "https://grafana.home.cwbtech.net/api/users"

# Organization management
curl -k -H "Authorization: Bearer $API_TOKEN" \
  "https://grafana.home.cwbtech.net/api/org"
```

## Security

### Access Control

- **Istio VirtualService**: Controls external access with TLS
- **Basic Authentication**: Optional HTTP basic auth layer
- **Local Users**: Grafana's built-in user management
- **Anonymous Access**: Disabled for security

### Data Protection

- **HTTPS Only**: All access via TLS
- **Session Management**: Secure cookie handling
- **API Security**: Token-based API access

### Network Security

```yaml
# Network policy example
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: grafana-network-policy
  namespace: monitoring
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: grafana
  policyTypes:
    - Ingress
    - Egress
```

## Best Practices

### Dashboard Design

1. **Consistent Layout**: Use similar panel sizes and arrangements
2. **Meaningful Names**: Clear titles and descriptions
3. **Appropriate Time Ranges**: Match refresh rates to data frequency
4. **Color Coding**: Consistent color schemes across dashboards
5. **Drill-down Links**: Enable navigation between related dashboards

### Query Optimization

1. **Use Variables**: Create reusable dashboard templates
2. **Efficient Queries**: Avoid high-cardinality aggregations
3. **Recording Rules**: Pre-calculate expensive queries in Prometheus
4. **Query Caching**: Leverage Grafana's query result caching

### Alert Management

1. **Meaningful Alerts**: Alert on symptoms, not causes
2. **Appropriate Thresholds**: Avoid alert fatigue with proper tuning
3. **Clear Annotations**: Provide context and remediation steps
4. **Notification Routing**: Send alerts to appropriate teams

## Resources

- **Grafana Documentation**: https://grafana.com/docs/
- **Dashboard Examples**: https://grafana.com/grafana/dashboards/
- **Prometheus Integration**: https://grafana.com/docs/grafana/latest/datasources/prometheus/
- **Loki Integration**: https://grafana.com/docs/grafana/latest/datasources/loki/
