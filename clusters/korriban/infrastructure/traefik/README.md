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
Internet → NodePort/LoadBalancer → Traefik → Services → Pods
    ↓              ↓                   ↓          ↓        ↓
  Port 80/443   External LB         Routing   Service   Application
```

## Configuration

### Service Configuration

Traefik is deployed as a NodePort service with MetalLB integration:

```yaml
service:
  type: NodePort
  annotations:
    metallb.universe.tf/address-pool: default
```

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
        - app.home.example.com
      secretName: app-tls
  rules:
    - host: app.home.example.com
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

For advanced routing, use Traefik's custom resources:

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: app-ingressroute
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`app.home.example.com`)
      kind: Rule
      services:
        - name: app-service
          port: 80
      middlewares:
        - name: auth-middleware
  tls:
    secretName: app-tls
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
    secret: auth-secret
```

#### Rate Limiting

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: rate-limit
spec:
  rateLimit:
    burst: 100
    average: 50
```

#### Headers

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: security-headers
spec:
  headers:
    customRequestHeaders:
      X-Forwarded-Proto: https
    customResponseHeaders:
      X-Frame-Options: DENY
      X-Content-Type-Options: nosniff
```

## Dashboard Access

### Port Forward (Development)

```bash
# Access dashboard locally
kubectl port-forward -n traefik-system svc/traefik 9000:9000
# Open http://localhost:9000/dashboard/
```

### Secure Dashboard (Production)

Create an IngressRoute with authentication:

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: traefik-dashboard
  namespace: traefik-system
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`traefik.home.example.com`)
      kind: Rule
      services:
        - name: api@internal
          kind: TraefikService
      middlewares:
        - name: auth-middleware
  tls:
    secretName: traefik-dashboard-tls
```

## Monitoring and Troubleshooting

### Health Checks

```bash
# Check Traefik pods
kubectl get pods -n traefik-system

# Check Traefik service
kubectl get svc -n traefik-system

# Check ingress resources
kubectl get ingress -A
kubectl get ingressroutes -A
```

### Service Status

```bash
# Check Traefik configuration
kubectl logs -n traefik-system -l app.kubernetes.io/name=traefik

# View Traefik configuration dump
kubectl exec -n traefik-system deployment/traefik -- traefik version
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
```

**Solutions**:

- Verify service is running and has endpoints
- Check ingress annotations and rules
- Ensure correct ingress class
- Verify TLS configuration

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

#### Load Balancer Not Accessible

**Symptoms**: External access to Traefik fails

**Diagnosis**:

```bash
# Check service type and external IP
kubectl get svc -n traefik-system

# Check MetalLB configuration
kubectl get configmap -n metallb-system

# Check node ports
kubectl get svc traefik -n traefik-system -o yaml
```

**Solutions**:

- Verify MetalLB is running
- Check firewall rules
- Verify network connectivity
- Check cloud provider load balancer configuration

### Logs and Debugging

```bash
# Traefik access logs
kubectl logs -n traefik-system -l app.kubernetes.io/name=traefik

# Follow logs in real-time
kubectl logs -n traefik-system -l app.kubernetes.io/name=traefik -f

# Check Traefik configuration
kubectl exec -n traefik-system deployment/traefik -- cat /etc/traefik/traefik.yml
```

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
```

### Connection Limits

```yaml
entryPoints:
  web:
    address: ":80"
    transport:
      lifeCycle:
        requestAcceptGraceTimeout: 0s
        graceTimeOut: 10s
  websecure:
    address: ":443"
    transport:
      lifeCycle:
        requestAcceptGraceTimeout: 0s
        graceTimeOut: 10s
```

## Security Configuration

### TLS Settings

```yaml
tls:
  options:
    default:
      minVersion: "VersionTLS12"
      cipherSuites:
        - "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
        - "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305"
        - "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
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

### Network Policies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: traefik-netpol
  namespace: traefik-system
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: traefik
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from: [] # Allow all ingress traffic
  egress:
    - to: [] # Allow all egress traffic
```

## Integration with Other Components

### Cert Manager Integration

Automatic certificate management:

```yaml
annotations:
  cert-manager.io/cluster-issuer: letsencrypt-cloudflare
```

### Prometheus Integration

Metrics are automatically exported on port 9100:

```yaml
metrics:
  prometheus:
    addEntryPointsLabels: true
    addServicesLabels: true
    addRoutersLabels: true
```

### External Secrets Integration

For managing sensitive configuration:

```yaml
# Reference external secrets for middleware auth
spec:
  basicAuth:
    secret: external-auth-secret
```

## Advanced Configuration

### Custom Middleware Chain

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: advanced-route
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`app.home.cwbtech.net`)
      kind: Rule
      services:
        - name: app-service
          port: 80
      middlewares:
        - name: security-headers
        - name: rate-limit
        - name: basic-auth
  tls:
    secretName: app-tls
```

### TCP/UDP Services

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRouteTCP
metadata:
  name: database-tcp
spec:
  entryPoints:
    - postgres
  routes:
    - match: HostSNI(`*`)
      services:
        - name: postgresql
          port: 5432
```

## Backup and Recovery

### Configuration Backup

```bash
# Backup Traefik configuration
kubectl get ingressroutes -A -o yaml > backup/ingressroutes-$(date +%Y%m%d).yaml
kubectl get middlewares -A -o yaml > backup/middlewares-$(date +%Y%m%d).yaml
kubectl get ingress -A -o yaml > backup/ingress-$(date +%Y%m%d).yaml

# Backup Traefik deployment
kubectl get deployment traefik -n traefik-system -o yaml > backup/traefik-deployment-$(date +%Y%m%d).yaml
```

### Disaster Recovery

1. **Restore Traefik deployment**
2. **Apply ingress configurations**
3. **Verify certificate automation**
4. **Test routing functionality**

## Best Practices

1. **Use HTTPS Everywhere**: Redirect HTTP to HTTPS
2. **Implement Rate Limiting**: Protect against abuse
3. **Security Headers**: Add security-focused HTTP headers
4. **Monitor Metrics**: Use Prometheus integration
5. **Health Checks**: Configure proper readiness/liveness probes
6. **Resource Limits**: Set appropriate CPU/memory limits
7. **Network Policies**: Restrict network access
8. **Regular Updates**: Keep Traefik version current

## Troubleshooting Checklist

- [ ] Check Traefik pods are running
- [ ] Verify service has external access
- [ ] Confirm ingress resources are created
- [ ] Check certificate status
- [ ] Verify DNS resolution
- [ ] Test backend service connectivity
- [ ] Review Traefik logs for errors
- [ ] Validate middleware configuration

## Resources

- **Traefik Documentation**: https://doc.traefik.io/traefik/
- **Kubernetes Integration**: https://doc.traefik.io/traefik/providers/kubernetes-ingress/
- **IngressRoute Guide**: https://doc.traefik.io/traefik/providers/kubernetes-crd/
- **Middleware Documentation**: https://doc.traefik.io/traefik/middlewares/overview/
