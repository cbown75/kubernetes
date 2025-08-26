# Istio Service Mesh

## Overview

Istio is a service mesh that provides advanced traffic management, security, and observability features for your Kubernetes cluster. In this setup, Istio also serves as the primary ingress controller, replacing the need for traditional ingress controllers.

## Features

- **Advanced Traffic Management**: Load balancing, circuit breaking, retries, failovers
- **Security**: Automatic mTLS, authentication and authorization policies
- **Observability**: Distributed tracing, metrics, and access logs
- **Ingress Gateway**: LoadBalancer service for external traffic entry
- **Certificate Management**: Integration with cert-manager for TLS

## Architecture

```
Internet → LoadBalancer (MetalLB) → Istio Gateway → VirtualService → Service → Pods
    ↓              ↓                      ↓              ↓            ↓        ↓
  Port 80/443   10.10.7.210        Traffic Rules   Routing     Service   Application
```

## Configuration

### Gateway Configuration

Istio is deployed with a public gateway that handles all external traffic:

```yaml
service:
  type: LoadBalancer
  loadBalancerIP: 10.10.7.210
  annotations:
    metallb.universe.tf/address-pool: default
  externalTrafficPolicy: Local
```

### Network Details

- **LoadBalancer IP**: `10.10.7.210` (assigned by MetalLB)
- **External Access**: Standard ports 80 (HTTP) and 443 (HTTPS)
- **Internal Communication**: mTLS enabled between services

### TLS Configuration

Istio uses a wildcard certificate managed by cert-manager:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: istio-gw-wildcard-home-cwbtech
  namespace: istio-system
spec:
  secretName: istio-gw-tls
  dnsNames:
    - "*.home.cwbtech.net"
  issuerRef:
    kind: ClusterIssuer
    name: letsencrypt-cloudflare
```

## Usage

### Basic Service Exposure

To expose a service through Istio, create a VirtualService:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: my-app
  namespace: my-namespace
spec:
  hosts:
    - "my-app.home.cwbtech.net"
  gateways:
    - istio-system/public-gw
  http:
    - match:
        - uri:
            prefix: /
      route:
        - destination:
            host: my-app.my-namespace.svc.cluster.local
            port:
              number: 80
```

### Traffic Management Examples

#### Canary Deployment

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: canary-deployment
spec:
  hosts:
    - "app.home.cwbtech.net"
  gateways:
    - istio-system/public-gw
  http:
    - match:
        - headers:
            canary:
              exact: "true"
      route:
        - destination:
            host: app-canary
            port:
              number: 80
    - route:
        - destination:
            host: app-stable
            port:
              number: 80
          weight: 90
        - destination:
            host: app-canary
            port:
              number: 80
          weight: 10
```

#### Circuit Breaker

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: circuit-breaker
spec:
  host: my-app.my-namespace.svc.cluster.local
  trafficPolicy:
    outlierDetection:
      consecutive5xxErrors: 3
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
```

## Access URLs

With MetalLB providing the LoadBalancer IP (10.10.7.210), services are accessible at:

- **Any VirtualService**: https://\<hostname\>.home.cwbtech.net
- **Direct IP Access**: https://10.10.7.210 (will show default backend or 404)

### Current Exposed Services

- **Grafana**: https://grafana.home.cwbtech.net
- **Prometheus**: https://prometheus.home.cwbtech.net
- **AlertManager**: https://alertmanager.home.cwbtech.net
- **Loki**: https://loki.home.cwbtech.net

## Monitoring and Troubleshooting

### Health Checks

```bash
# Check Istio pods
kubectl get pods -n istio-system

# Check Istio gateway service and LoadBalancer IP
kubectl get svc -n istio-system
# Should show EXTERNAL-IP as 10.10.7.210

# Check gateway and VirtualService resources
kubectl get gateway -A
kubectl get virtualservice -A
```

### Service Status

```bash
# Check Istio proxy logs
kubectl logs -n istio-system -l app=istio-proxy

# Check istiod logs
kubectl logs -n istio-system -l app=istiod

# Check gateway configuration
istioctl proxy-config routes istio-ingress -n istio-system
```

### Test Connectivity

```bash
# Test LoadBalancer IP
curl -v http://10.10.7.210
curl -v https://10.10.7.210

# Test specific service
curl -v https://prometheus.home.cwbtech.net

# Check certificate
openssl s_client -connect prometheus.home.cwbtech.net:443 -servername prometheus.home.cwbtech.net
```

### Common Issues and Solutions

#### VirtualService Not Working

**Symptoms**: Service not accessible through gateway

**Diagnosis**:

```bash
# Check VirtualService status
kubectl describe virtualservice <vs-name> -n <namespace>

# Check gateway configuration
kubectl describe gateway public-gw -n istio-system

# Verify service endpoints
kubectl get endpoints <service-name> -n <namespace>

# Check LoadBalancer IP
kubectl get svc -n istio-system istio-ingress
```

**Solutions**:

- Verify service is running and has endpoints
- Check VirtualService host and gateway references
- Ensure DNS points to 10.10.7.210
- Verify gateway selector matches ingress deployment

#### TLS Certificate Issues

**Symptoms**: HTTPS not working or certificate errors

**Diagnosis**:

```bash
# Check certificate status
kubectl get certificates -A

# Check TLS secret in istio-system
kubectl get secret istio-gw-tls -n istio-system -o yaml

# Test TLS connection
openssl s_client -connect <host>:443 -servername <host>
```

**Solutions**:

- Verify cert-manager is working
- Check ClusterIssuer configuration
- Ensure DNS is properly configured
- Wait for certificate issuance

#### LoadBalancer IP Not Assigned

**Symptoms**: Service shows \<pending\> for EXTERNAL-IP

**Diagnosis**:

```bash
# Check MetalLB is running
kubectl get pods -n metallb-system

# Check IP pool availability
kubectl describe ipaddresspool -n metallb-system

# Check service events
kubectl describe svc istio-ingress -n istio-system
```

**Solutions**:

- Ensure MetalLB is deployed and running
- Verify IP pool has available addresses
- Check MetalLB controller logs

## Performance Tuning

### Resource Configuration

```yaml
# Istio proxy sidecar resources
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 2000m
    memory: 1024Mi
```

### Gateway Scaling

```yaml
# Ingress gateway autoscaling
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 80
```

### Connection Limits

```yaml
# Gateway configuration
pilot:
  env:
    EXTERNAL_ISTIOD: false
    PILOT_ENABLE_WORKLOAD_ENTRY_AUTOREGISTRATION: true
meshConfig:
  defaultConfig:
    connectionTimeout: 10s
    drainDuration: 45s
```

## Security Configuration

### mTLS Settings

```yaml
# Namespace-wide mTLS policy
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT
```

### Authorization Policies

```yaml
# Service-level authorization
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-frontend
  namespace: production
spec:
  selector:
    matchLabels:
      app: backend
  rules:
    - from:
        - source:
            principals: ["cluster.local/ns/production/sa/frontend"]
      to:
        - operation:
            methods: ["GET", "POST"]
```

## Integration with Other Components

### MetalLB

- Provides LoadBalancer IP (10.10.7.210)
- Handles ARP announcements
- Manages failover between nodes

### Cert-Manager

- Automatic TLS certificate provisioning
- Wildcard certificate for \*.home.cwbtech.net
- Integration via Certificate resources

### Prometheus

- Service mesh metrics collection
- Automatic sidecar injection for telemetry
- Grafana dashboards for Istio observability

## Observability

### Distributed Tracing

```bash
# Enable tracing for a namespace
kubectl label namespace production istio-injection=enabled

# Check trace sampling
kubectl get configmap istio -n istio-system -o yaml | grep -A 5 -B 5 tracing
```

### Metrics Collection

```bash
# Check Istio metrics
kubectl exec -n istio-system deployment/istiod -- pilot-discovery request GET /stats/prometheus

# Port forward to Grafana for Istio dashboards
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
```

### Access Logs

```bash
# Enable access logs
kubectl patch configmap istio -n istio-system --type merge -p '{"data":{"mesh":"accessLogFile: /dev/stdout"}}'

# View proxy access logs
kubectl logs -n <namespace> <pod-name> -c istio-proxy
```

## Maintenance

### Updating Istio

Edit `infrastructure/istio/release.yaml` to update versions:

```yaml
spec:
  chart:
    spec:
      chart: istiod
      version: "1.20.0" # Update version
```

Then commit and push for GitOps deployment.

### Canary Upgrades

Istio supports canary upgrades for safer updates:

```bash
# Check current revision
kubectl get pods -n istio-system -l app=istiod --show-labels

# Deploy new revision
kubectl apply -f istio-1.21.yaml

# Migrate workloads gradually
kubectl label namespace production istio.io/rev=1-21 istio-injection-
```

## Resources

- **Istio Documentation**: https://istio.io/latest/docs/
- **Traffic Management**: https://istio.io/latest/docs/concepts/traffic-management/
- **Security**: https://istio.io/latest/docs/concepts/security/
- **Observability**: https://istio.io/latest/docs/concepts/observability/
- **Gateway API**: https://gateway-api.sigs.k8s.io/
