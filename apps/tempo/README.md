# Tempo

## Overview

Tempo is Grafana's distributed tracing backend that provides scalable trace storage and retrieval for OpenTelemetry, Jaeger, and Zipkin traces.

## Features

- **Multi-Protocol Support**: OTLP, Jaeger, Zipkin
- **Distributed Tracing**: Track requests across microservices
- **Low Cost**: Efficient object storage backend
- **TraceQL**: Powerful query language for traces
- **Metrics Generation**: Automatic service graphs and span metrics

## Architecture

This Tempo deployment uses a **multi-cluster structure** with Kustomize overlays:

```
/apps/tempo/
  base/                           # Shared configuration
    namespace.yaml                # monitoring namespace
    serviceaccount.yaml          # Tempo service account
    statefulset.yaml             # Main StatefulSet
    configmap.yaml               # Tempo configuration
    service.yaml                 # ClusterIP service
    kustomization.yaml

  overlay/
    korriban/                    # Korriban cluster-specific
      patches/
        storage-patch.yaml       # synology-holocron-general
      istio-routing.yaml         # VirtualService
      kustomization.yaml
```

## Configuration

### Storage

- **Backend**: Local filesystem storage
- **Retention**: 30 days
- **Storage Class**: synology-holocron-general (100Gi)

### Ingestion Endpoints

- **OTLP gRPC**: Port 4317
- **OTLP HTTP**: Port 4318
- **Jaeger gRPC**: Port 14250
- **Jaeger Thrift HTTP**: Port 14268
- **Zipkin**: Port 9411

### Web Interface

Access Tempo at: https://tempo.home.cwbtech.net

## Integration with Grafana

Add Tempo as a data source in Grafana:

1. Navigate to Configuration → Data Sources
2. Add new data source → Tempo
3. URL: `http://tempo.monitoring.svc.cluster.local:3200`
4. Save & Test

## Sending Traces

### OpenTelemetry (Recommended)

```yaml
# OTEL Collector configuration
exporters:
  otlp:
    endpoint: tempo.monitoring.svc.cluster.local:4317
    tls:
      insecure: true
```

### Jaeger

```yaml
# Jaeger agent configuration
JAEGER_ENDPOINT: http://tempo.monitoring.svc.cluster.local:14268/api/traces
```

### Zipkin

```yaml
# Zipkin configuration
ZIPKIN_ENDPOINT: http://tempo.monitoring.svc.cluster.local:9411
```

## TraceQL Queries

```traceql
# Find all traces with errors
{ status = error }

# Find slow traces (>1s duration)
{ duration > 1s }

# Find traces for a specific service
{ service.name = "my-service" }

# Complex query
{
  service.name = "frontend" &&
  span.http.status_code >= 500 &&
  duration > 2s
}
```

## Monitoring

Tempo exposes Prometheus metrics at `/metrics`:

```promql
# Ingested spans per second
rate(tempo_distributor_spans_received_total[5m])

# Query latency
histogram_quantile(0.99, tempo_query_frontend_duration_seconds_bucket)

# Storage usage
tempo_ingester_bytes_metric_total
```

## Troubleshooting

### Check Tempo Status

```bash
# Verify pod is running
kubectl get pods -n monitoring -l app=tempo

# Check logs
kubectl logs -n monitoring -l app=tempo --tail=100

# Check readiness
kubectl get pod -n monitoring -l app=tempo -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}'
```

### Test Trace Ingestion

```bash
# Send test trace via OTLP
kubectl run otel-test --image=otel/opentelemetry-collector-contrib:latest --rm -it --restart=Never -- \
  /bin/sh -c "echo 'Testing OTLP endpoint...'"
```

### Common Issues

1. **Traces not appearing**: Check ingestion endpoints are reachable
2. **Storage full**: Adjust retention or increase PVC size
3. **High memory usage**: Reduce compaction workers or increase limits

## Resources

- **Tempo Documentation**: https://grafana.com/docs/tempo/
- **TraceQL**: https://grafana.com/docs/tempo/latest/traceql/
- **OpenTelemetry**: https://opentelemetry.io/
