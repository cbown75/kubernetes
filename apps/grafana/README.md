# Grafana

## Overview

Grafana is an open-source analytics and interactive visualization platform that allows you to query, visualize, alert on, and understand your metrics no matter where they are stored. In this deployment, Grafana serves as the primary dashboard and visualization layer for your monitoring stack.

## Features

- **Rich Visualizations**: Graphs, tables, heatmaps, histograms, and more
- **Dashboard Management**: Organize panels into customizable dashboards
- **Multiple Data Sources**: Prometheus, Loki, and external sources
- **Alerting**: Visual alert rules with notification channels
- **User Management**: Authentication and authorization
- **Auto-Discovery**: Automatic dashboard loading via sidecar

## Architecture

This Grafana deployment uses a **multi-cluster structure** with Kustomize overlays:

```
/apps/grafana/
  base/                           # Shared configuration across all clusters
    namespace.yaml                # monitoring namespace
    serviceaccount.yaml          # Grafana service account
    deployment.yaml              # Main deployment with sidecar
    service.yaml                 # ClusterIP service
    pvc.yaml                     # PVC template
    configmap-datasources.yaml   # Prometheus & Loki datasources
    configmap-grafana-ini.yaml   # Base grafana.ini config
    kustomization.yaml

  overlay/
    korriban/                    # Korriban cluster-specific
      patches/
        domain-patch.yaml        # grafana.home.cwbtech.net
        storage-patch.yaml       # nfs-holocron-general
      sealed-secrets.yaml        # Admin credentials
      istio-routing.yaml         # VirtualService
      kustomization.yaml

    moraband/                    # Future cluster
    dathomir/                    # Future cluster
```

## Configuration

### Deployment Details

- **Namespace**: `monitoring`
- **Replicas**: 1 (Recreate strategy due to PVC)
- **Storage**: 10Gi PersistentVolumeClaim
- **Image**: grafana/grafana:11.4.0
- **Authentication**: Local admin user via sealed secrets

### Cluster-Specific Configuration

Each cluster overlay customizes:

| Setting               | Korriban                  | Other Clusters            |
| --------------------- | ------------------------- | ------------------------- |
| **Domain**            | grafana.home.cwbtech.net  | Set in overlay            |
| **Storage Class**     | nfs-holocron-general      | Set in overlay            |
| **Admin Credentials** | Sealed secret per cluster | Sealed secret per cluster |

### Data Sources

Pre-configured data sources (defined in base):

#### Prometheus

- **URL**: `http://prometheus-server.monitoring.svc.cluster.local:9090`
- **Type**: Time-series metrics
- **Usage**: Primary metrics source for all dashboards

#### Loki

- **URL**: `http://loki.monitoring.svc.cluster.local:3100`
- **Type**: Log aggregation
- **Usage**: Log exploration and correlation with metrics

### Dashboard Auto-Discovery

Grafana includes a **sidecar container** that automatically discovers and loads dashboards:

- **Watches**: ConfigMaps with label `grafana_dashboard=1`
- **Namespace**: ALL (searches entire cluster)
- **Auto-reload**: Dashboards update automatically when ConfigMaps change

**To add a dashboard:**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  dashboard.json: |
    {
      "dashboard": { ... }
    }
```

### Resource Allocation

**Grafana Container:**

```yaml
resources:
  requests:
    cpu: 250m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

**Dashboard Sidecar:**

```yaml
resources:
  requests:
    cpu: 50m
    memory: 50Mi
  limits:
    cpu: 100m
    memory: 100Mi
```

### Security Context

```yaml
securityContext:
  runAsUser: 472
  runAsGroup: 472
  fsGroup: 472
  runAsNonRoot: true
```

## Access and Authentication

### Login Credentials

Admin credentials are managed via sealed secrets per cluster:

- **Admin User**: Configured via sealed secret `grafana-admin-secret`
- **Admin Password**: Configured via sealed secret `grafana-admin-secret`

### External Access

Access Grafana through Istio ingress with automatic TLS termination:

- **Korriban**: https://grafana.home.cwbtech.net
- **Other clusters**: Configured in cluster overlay

### Authentication Methods

1. **Local Users**: Built-in user database
2. **Anonymous Access**: Disabled by default

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

1. **Access Grafana UI**: Navigate to your cluster's Grafana URL
2. **Create Dashboard**: Click "+" → "Dashboard"
3. **Add Panels**: Choose visualization type and configure queries
4. **Save Dashboard**: Save with descriptive name and tags
5. **Export as ConfigMap**: Export JSON and create ConfigMap with `grafana_dashboard=1` label

### Importing Dashboards

**Method 1: Via ConfigMap (GitOps)**

```bash
# Create ConfigMap from dashboard JSON
kubectl create configmap my-dashboard \
  --from-file=dashboard.json \
  --namespace=monitoring \
  --dry-run=client -o yaml | \
  kubectl label --local -f - grafana_dashboard=1 --dry-run=client -o yaml \
  > my-dashboard.yaml
```

**Method 2: Via Grafana UI**

1. Navigate to Dashboards → Import
2. Upload JSON file or paste dashboard ID from grafana.com
3. Select data sources
4. Import

### Dashboard Best Practices

1. **Consistent Layout**: Use similar panel sizes and arrangements
2. **Meaningful Names**: Clear titles and descriptions
3. **Appropriate Time Ranges**: Match refresh rates to data frequency
4. **Color Coding**: Consistent color schemes across dashboards
5. **Drill-down Links**: Enable navigation between related dashboards

## Query Optimization

1. **Use Variables**: Create reusable dashboard templates
2. **Efficient Queries**: Avoid high-cardinality aggregations
3. **Recording Rules**: Pre-calculate expensive queries in Prometheus
4. **Query Caching**: Leverage Grafana's query result caching

### Example Variable Queries

```promql
# Namespace variable
label_values(kube_pod_info, namespace)

# Node variable
label_values(kube_node_info, node)

# Pod variable (filtered by namespace)
label_values(kube_pod_info{namespace="$namespace"}, pod)
```

### Using Variables in Queries

```promql
# Use variables in queries
rate(container_cpu_usage_seconds_total{namespace="$namespace", pod="$pod"}[5m])
```

## Management

### Status Checks

```bash
# Check Grafana pod
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana

# Check service
kubectl get svc -n monitoring grafana

# Check Istio routing
kubectl get virtualservice -n monitoring grafana

# Verify storage
kubectl get pvc -n monitoring grafana-pvc
```

### Configuration Management

```bash
# Check Grafana configuration
kubectl get configmap -n monitoring grafana-config

# View datasources
kubectl get configmap -n monitoring grafana-datasources

# View current settings
kubectl exec -n monitoring deployment/grafana -- cat /etc/grafana/grafana.ini
```

### Health Monitoring

```bash
# Health check endpoint
curl -k https://grafana.home.cwbtech.net/api/health

# Check data source connectivity
curl -k https://grafana.home.cwbtech.net/api/datasources/proxy/1/api/v1/query?query=up
```

### Logs

```bash
# View Grafana logs
kubectl logs -n monitoring deployment/grafana -c grafana

# View sidecar logs
kubectl logs -n monitoring deployment/grafana -c grafana-sc-dashboard

# Follow logs
kubectl logs -n monitoring deployment/grafana -c grafana --follow
```

## Troubleshooting

### Common Issues

#### Cannot Access Dashboard

```bash
# Check pod status
kubectl describe pod -n monitoring -l app=grafana

# Check logs
kubectl logs -n monitoring deployment/grafana -c grafana

# Verify Istio routing
kubectl describe virtualservice -n monitoring grafana

# Check if service is up
kubectl get svc -n monitoring grafana
```

#### Data Source Connection Errors

```bash
# Test Prometheus connectivity from Grafana pod
kubectl exec -n monitoring deployment/grafana -c grafana -- \
  wget -O- http://prometheus-server.monitoring.svc.cluster.local:9090/api/v1/query?query=up

# Test Loki connectivity
kubectl exec -n monitoring deployment/grafana -c grafana -- \
  wget -O- http://loki.monitoring.svc.cluster.local:3100/ready

# Check network policies
kubectl describe networkpolicy -n monitoring
```

#### Dashboard Not Loading

```bash
# Check Grafana logs for errors
kubectl logs -n monitoring deployment/grafana -c grafana | grep -i error

# Verify dashboard ConfigMaps
kubectl get configmap -n monitoring -l grafana_dashboard=1

# Check sidecar logs
kubectl logs -n monitoring deployment/grafana -c grafana-sc-dashboard
```

#### Authentication Issues

```bash
# Check sealed secrets
kubectl get sealedsecret -n monitoring grafana-admin-secret

# Verify secret creation
kubectl get secret -n monitoring grafana-admin-secret -o yaml

# Verify secret is mounted
kubectl describe pod -n monitoring -l app=grafana | grep -A 10 Mounts
```

#### Sidecar Not Loading Dashboards

```bash
# Check sidecar logs
kubectl logs -n monitoring deployment/grafana -c grafana-sc-dashboard

# Verify ConfigMap labels
kubectl get configmap -n monitoring -l grafana_dashboard=1

# Check RBAC permissions
kubectl auth can-i list configmaps --as=system:serviceaccount:monitoring:grafana -n monitoring
```

### Performance Issues

#### Slow Dashboard Loading

- **Reduce query complexity**: Simplify PromQL queries
- **Optimize time ranges**: Use appropriate time ranges for panels
- **Cache settings**: Adjust query caching in Grafana settings
- **Check Prometheus**: Verify Prometheus performance

#### High Memory Usage

```bash
# Check memory usage
kubectl top pod -n monitoring -l app=grafana

# Review memory settings
kubectl describe pod -n monitoring -l app=grafana | grep -A 5 memory

# Check if PVC is full
kubectl exec -n monitoring deployment/grafana -c grafana -- df -h /var/lib/grafana
```

## Backup and Recovery

### Dashboard Backup

**Method 1: Export via ConfigMaps**

```bash
# Export all dashboard ConfigMaps
kubectl get configmap -n monitoring -l grafana_dashboard=1 -o yaml > grafana-dashboards-backup.yaml
```

**Method 2: Export via API**

```bash
# Individual dashboard export
curl -k -H "Authorization: Bearer $API_TOKEN" \
  "https://grafana.home.cwbtech.net/api/dashboards/uid/$DASHBOARD_UID" > dashboard.json
```

### Data Backup

```bash
# Grafana database backup (if using SQLite)
kubectl exec -n monitoring deployment/grafana -c grafana -- \
  tar czf /tmp/grafana-data.tar.gz /var/lib/grafana/grafana.db

# Copy backup locally
kubectl cp monitoring/$(kubectl get pod -n monitoring -l app=grafana -o jsonpath='{.items[0].metadata.name}'):/tmp/grafana-data.tar.gz \
  ./grafana-backup-$(date +%Y%m%d).tar.gz -c grafana
```

### Configuration Backup

All configuration is managed via GitOps and stored in the git repository:

- Base configuration: `/apps/grafana/base/`
- Cluster-specific: `/apps/grafana/overlay/<cluster>/`

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

# Delete dashboard
curl -k -X DELETE -H "Authorization: Bearer $API_TOKEN" \
  "https://grafana.home.cwbtech.net/api/dashboards/uid/$UID"
```

### User Management API

```bash
# List users
curl -k -H "Authorization: Bearer $API_TOKEN" \
  "https://grafana.home.cwbtech.net/api/users"

# Create user
curl -k -X POST -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"John Doe","email":"john@example.com","login":"john","password":"password"}' \
  "https://grafana.home.cwbtech.net/api/admin/users"

# Organization management
curl -k -H "Authorization: Bearer $API_TOKEN" \
  "https://grafana.home.cwbtech.net/api/org"
```

### Data Source API

```bash
# List all data sources
curl -k -H "Authorization: Bearer $API_TOKEN" \
  "https://grafana.home.cwbtech.net/api/datasources"

# Test data source
curl -k -H "Authorization: Bearer $API_TOKEN" \
  "https://grafana.home.cwbtech.net/api/datasources/proxy/1/api/v1/query?query=up"
```

## Security

### Access Control

- **Istio VirtualService**: Controls external access with TLS
- **Local Users**: Grafana's built-in user management
- **Anonymous Access**: Disabled for security
- **Service Account**: Dedicated Kubernetes service account

### Data Protection

- **HTTPS Only**: All access via TLS through Istio
- **Session Management**: Secure cookie handling
- **API Security**: Token-based API access
- **Sealed Secrets**: Encrypted credentials in git

### Network Security

```yaml
# Example Network Policy for Grafana
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: grafana-network-policy
  namespace: monitoring
spec:
  podSelector:
    matchLabels:
      app: grafana
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: istio-system
      ports:
        - protocol: TCP
          port: 3000
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              name: monitoring
      ports:
        - protocol: TCP
          port: 9090 # Prometheus
        - protocol: TCP
          port: 3100 # Loki
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 53 # DNS
        - protocol: UDP
          port: 53 # DNS
```

## Adding New Clusters

To deploy Grafana to a new cluster (e.g., Moraband):

1. **Create overlay directory**:

   ```bash
   mkdir -p apps/grafana/overlay/moraband/patches
   ```

2. **Create kustomization.yaml**:

   ```yaml
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   namespace: monitoring
   resources:
     - ../../base
     - sealed-secrets.yaml
     - istio-routing.yaml
   commonAnnotations:
     app.kubernetes.io/instance: moraband
   patches:
     - path: patches/domain-patch.yaml
       target:
         kind: ConfigMap
         name: grafana-config
   patchesStrategicMerge:
     - patches/storage-patch.yaml
   ```

3. **Create domain patch** with cluster-specific domain

4. **Create storage patch** with cluster-specific storage class

5. **Create sealed secrets** for admin credentials

6. **Create Istio routing** for cluster's domain

7. **Reference in cluster directory**:
   ```yaml
   # clusters/moraband/apps/grafana/kustomization.yaml
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   resources:
     - ../../../../apps/grafana/overlay/moraband
   ```

## Best Practices

1. **Dashboard Organization**: Use folders and tags to organize dashboards
2. **Version Control**: Export important dashboards as ConfigMaps in git
3. **Resource Monitoring**: Monitor Grafana's own resource usage
4. **Regular Updates**: Keep Grafana image version updated
5. **Backup Strategy**: Regular exports of critical dashboards
6. **Alert Configuration**: Set up alerts for Grafana availability

## Resources

- **Grafana Documentation**: https://grafana.com/docs/
- **Dashboard Examples**: https://grafana.com/grafana/dashboards/
- **Prometheus Integration**: https://grafana.com/docs/grafana/latest/datasources/prometheus/
- **Loki Integration**: https://grafana.com/docs/grafana/latest/datasources/loki/
- **Sidecar Documentation**: https://github.com/kiwigrid/k8s-sidecar
