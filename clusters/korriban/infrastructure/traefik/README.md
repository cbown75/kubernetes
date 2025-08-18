# Traefik Ingress Controller

## Overview

Traefik is a modern HTTP reverse proxy and load balancer that makes deploying microservices easy. It integrates seamlessly with Kubernetes and automatically discovers services.

## Features

- **Automatic Service Discovery**: Automatically detects new services and routes
- **Let's Encrypt Integration**: Automatic TLS certificate management with cert-manager
- **Load Balancing**: Multiple load balancing algorithms
- **Middleware Support**: Request/response transformation, authentication, rate limiting
- **Dashboard**: Web UI for monitoring and configuration
- **Metrics Export**: Prometheus metrics integration

## Architecture

```
Internet → LoadBalancer (MetalLB) → Traefik → Services → Pods
    ↓              ↓                    ↓          ↓        ↓
  Port 80/443   10.10.7.200         Routing   Service   Application
```

## Configuration

### Service Configuration

Traefik is deployed as a LoadBalancer service with MetalLB integration:

```yaml
service:
  type: LoadBalancer
  annotations:
    metallb.universe.tf/address-pool: default
  externalTrafficPolicy: Local # Preserves client IPs
```

### Network Details

- **LoadBalancer IP**: `10.10.7.200` (assigned by MetalLB)
- **External Access**: Standard ports 80 (HTTP) and 443 (HTTPS)
- **Internal Access**: Dashboard on port 9000, Metrics on port 9100

### Entry Points

- **web**: Port 80 (HTTP) with automatic redirect to HTTPS
- **websecure**: Port 443 (HTTPS) with TLS termination
- **traefik**: Port 9000 (Dashboard)
- **metrics**: Port 9100 (Prometheus metrics)

### Ingress Classes

Traefik is configured as the default ingress controller:

```yaml
ingressClass:
  enabled: true
  isDefaultClass: true
  name: traefik
```

## Usage

### Basic Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: basic-ingress
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    cert-manager.io/cluster-issuer: letsencrypt-cloudflare
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - app.home.cwbtech.net
      secretName: app-tls
  rules:
    - host: app.home.cwbtech.net
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app-service
                port:
                  number: 80
```

### IngressRoute (Traefik CRD)

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: app-ingressroute
  namespace: default
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`app.home.cwbtech.net`)
      kind: Rule
      services:
        - name: app-service
          port: 80
  tls:
    certResolver: letsencrypt
```

### Middleware Examples

#### Basic Authentication

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: basic-auth
spec:
  basicAuth:
    secret: auth-secret # Secret containing htpasswd
```

#### Rate Limiting

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: rate-limit
spec:
  rateLimit:
    average: 100
    burst: 50
```

#### HTTPS Redirect (Already Configured Globally)

```yaml
# Automatic redirect from HTTP to HTTPS is enabled by default
ports:
  web:
    redirections:
      entryPoint:
        to: websecure
        scheme: https
        permanent: true
```

## Access URLs

With MetalLB providing the LoadBalancer IP (10.10.7.200), services are accessible at:

- **Traefik Dashboard**: http://10.10.7.200:9000/dashboard/
- **Any Ingress**: https://<hostname>.home.cwbtech.net
- **Direct IP Access**: https://10.10.7.200 (will show default backend or 404)

## Monitoring and Troubleshooting

### Health Checks

```bash
# Check Traefik pods
kubectl get pods -n traefik-system

# Check Traefik service and LoadBalancer IP
kubectl get svc -n traefik-system
# Should show EXTERNAL-IP as 10.10.7.200

# Check ingress resources
kubectl get ingress -A
kubectl get ingressroutes -A
```

### Service Status

```bash
# Check Traefik logs
kubectl logs -n traefik-system -l app.kubernetes.io/name=traefik

# Follow logs in real-time
kubectl logs -n traefik-system -l app.kubernetes.io/name=traefik -f

# Check Traefik configuration
kubectl exec -n traefik-system deployment/traefik -- traefik version
```

### Test Connectivity

```bash
# Test LoadBalancer IP
curl -v http://10.10.7.200
curl -v https://10.10.7.200

# Test specific service
curl -v https://prometheus.home.cwbtech.net

# Check certificate
openssl s_client -connect prometheus.home.cwbtech.net:443 -servername prometheus.home.cwbtech.net
```

### Common Issues and Solutions

#### Ingress Not Working

**Symptoms**: Service not accessible through ingress

**Diagnosis**:

```bash
# Check ingress status
kubectl describe ingress <ingress-name> -n <namespace>

# Check Traefik logs
kubectl logs -n traefik-system -l app.kubernetes.io/name=traefik

# Verify service endpoints
kubectl get endpoints <service-name> -n <namespace>

# Check LoadBalancer IP
kubectl get svc -n traefik-system traefik-system-traefik
```

**Solutions**:

- Verify service is running and has endpoints
- Check ingress annotations and rules
- Ensure correct ingress class
- Verify DNS points to 10.10.7.200

#### TLS Certificate Issues

**Symptoms**: HTTPS not working or certificate errors

**Diagnosis**:

```bash
# Check certificate status
kubectl get certificates -A

# Check TLS secret
kubectl get secret <tls-secret> -n <namespace> -o yaml

# Test TLS connection
openssl s_client -connect <host>:443 -servername <host>
```

**Solutions**:

- Verify cert-manager is working
- Check ClusterIssuer configuration
- Ensure DNS is properly configured
- Wait for certificate issuance

#### LoadBalancer IP Not Assigned

**Symptoms**: Service shows <pending> for EXTERNAL-IP

**Diagnosis**:

```bash
# Check MetalLB is running
kubectl get pods -n metallb-system

# Check IP pool availability
kubectl describe ipaddresspool -n metallb-system

# Check service events
kubectl describe svc traefik-system-traefik -n traefik-system
```

**Solutions**:

- Ensure MetalLB is deployed and running
- Verify IP pool has available addresses
- Check MetalLB controller logs

## Performance Tuning

### Resource Limits

```yaml
resources:
  requests:
    cpu: 100m
    memory: 50Mi
  limits:
    cpu: 300m
    memory: 150Mi
```

### Scaling

```yaml
deployment:
  replicas: 2 # For high availability
  affinity:
    podAntiAffinity: # Spread across nodes
```

### Connection Limits

```yaml
entryPoints:
  web:
    transport:
      lifeCycle:
        requestAcceptGraceTimeout: 0s
        graceTimeOut: 10s
  websecure:
    transport:
      lifeCycle:
        requestAcceptGraceTimeout: 0s
        graceTimeOut: 10s
```

## Security Configuration

### TLS Settings

```yaml
tlsOptions:
  default:
    minVersion: VersionTLS12
    sniStrict: true
    cipherSuites:
      - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
      - TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305
      - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
```

### Security Context

```yaml
securityContext:
  capabilities:
    drop: [ALL]
    add: [NET_BIND_SERVICE]
  readOnlyRootFilesystem: true
  runAsGroup: 65532
  runAsNonRoot: true
  runAsUser: 65532
```

## Integration with Other Components

### MetalLB

- Provides LoadBalancer IP (10.10.7.200)
- Handles ARP announcements
- Manages failover between nodes

### Cert-Manager

- Automatic TLS certificate provisioning
- Integration via annotations
- Supports multiple ClusterIssuers

### Prometheus

- Metrics exported on port 9100
- ServiceMonitor for automatic discovery
- Key metrics: request rate, latency, errors

## Maintenance

### Updating Traefik

Edit `infrastructure/traefik/release.yaml`:

```yaml
spec:
  chart:
    spec:
      version: "28.2.0" # Update version
```

Then commit and push for GitOps deployment.

### Viewing Dashboard

```bash
# Port forward to access dashboard
kubectl port-forward -n traefik-system deployment/traefik 9000:9000

# Access at http://localhost:9000/dashboard/
```

Or configure an IngressRoute for permanent access.

## Resources

- **Traefik Documentation**: https://doc.traefik.io/traefik/
- **Kubernetes Integration**: https://doc.traefik.io/traefik/providers/kubernetes-ingress/
- **IngressRoute Guide**: https://doc.traefik.io/traefik/providers/kubernetes-crd/
- **Middleware Documentation**: https://doc.traefik.io/traefik/middlewares/overview/
