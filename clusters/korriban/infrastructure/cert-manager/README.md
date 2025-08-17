# Cert Manager - Automatic TLS Certificate Management

## Overview

Cert Manager automates the management and issuance of TLS certificates from various issuing sources. It ensures certificates are valid, up-to-date, and renews them before expiry.

## Features

- **Let's Encrypt Integration**: Automatic certificate issuance from Let's Encrypt
- **Cloudflare DNS Challenge**: DNS-01 challenge using Cloudflare API
- **Automatic Renewal**: Certificates renewed before expiration
- **Multiple Issuers**: Production and staging environments
- **Wildcard Certificates**: Support for `*.home.example.com` domains

## Configuration

### ClusterIssuers

Two ClusterIssuers are configured for different environments:

#### Production Issuer

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-cloudflare
spec:
  acme:
    email: your-email@example.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-cloudflare-key
    solvers:
      - dns01:
          cloudflare:
            apiTokenSecretRef:
              name: traefik-cloudflare
              key: CF_API_TOKEN
        selector:
          dnsZones:
            - "example.com"
            - "home.example.com"
```

#### Staging Issuer

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-cloudflare-staging
spec:
  acme:
    email: your-email@example.com
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    # ... similar configuration for testing
```

### DNS Challenge Configuration

Uses Cloudflare DNS-01 challenge for domain validation:

- **Domains**: `cwbtech.net` and `home.cwbtech.net`
- **API Token**: Stored as SealedSecret `traefik-cloudflare`
- **Validation**: Automatic DNS record creation/deletion

## Usage

### Automatic Certificate Issuance

Certificates are automatically issued when you create an Ingress with annotations:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-ingress
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-cloudflare
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - app.home.example.com
      secretName: app-tls-secret
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

### Manual Certificate Creation

You can also create certificates directly:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-cert
  namespace: default
spec:
  secretName: example-tls
  issuerRef:
    name: letsencrypt-cloudflare
    kind: ClusterIssuer
  dnsNames:
    - example.home.example.com
    - "*.example.home.example.com"
```

## Monitoring and Troubleshooting

### Health Checks

```bash
# Check cert-manager pods
kubectl get pods -n cert-manager

# Check ClusterIssuers
kubectl get clusterissuers

# List all certificates
kubectl get certificates -A

# Check certificate details
kubectl describe certificate <cert-name> -n <namespace>
```

### Certificate Status

```bash
# Check certificate ready status
kubectl get certificates -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,READY:.status.conditions[0].status,SECRET:.spec.secretName,AGE:.metadata.creationTimestamp

# Check certificate expiration
kubectl get certificates -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,EXPIRES:.status.notAfter,RENEWAL:.status.renewalTime
```

### Common Issues and Solutions

#### Certificate Stuck in Pending

**Symptoms**: Certificate shows "Ready: False" for extended period

**Diagnosis**:

```bash
kubectl describe certificate <cert-name> -n <namespace>
kubectl describe certificaterequest <cert-name>-xxx -n <namespace>
kubectl describe order <order-name> -n <namespace>
kubectl describe challenge <challenge-name> -n <namespace>
```

**Common Causes**:

- DNS propagation delay
- Cloudflare API rate limits
- Invalid DNS zone configuration
- Network connectivity issues

#### DNS Challenge Failures

**Symptoms**: Challenge fails during DNS validation

**Diagnosis**:

```bash
# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# Check Cloudflare API connectivity
kubectl exec -n cert-manager deployment/cert-manager -- \
  curl -H "Authorization: Bearer $(kubectl get secret traefik-cloudflare -n cert-manager -o jsonpath='{.data.CF_API_TOKEN}' | base64 -d)" \
  https://api.cloudflare.com/client/v4/user/tokens/verify
```

**Solutions**:

- Verify Cloudflare API token permissions
- Check DNS zone configuration
- Ensure network policies allow DNS access

#### Rate Limiting

**Symptoms**: Let's Encrypt rate limit errors

**Solutions**:

- Use staging issuer for testing
- Avoid recreating certificates frequently
- Check Let's Encrypt rate limits documentation

### Logs and Events

```bash
# Cert-manager controller logs
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager

# Webhook logs
kubectl logs -n cert-manager -l app.kubernetes.io/name=webhook

# CA injector logs
kubectl logs -n cert-manager -l app.kubernetes.io/name=cainjector

# Check events for certificate issues
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | grep -i cert
```

## Certificate Management

### Renewing Certificates

Certificates are automatically renewed when they reach 2/3 of their lifetime:

```bash
# Force certificate renewal
kubectl annotate certificate <cert-name> -n <namespace> cert-manager.io/force-renew="$(date +%s)"

# Check renewal status
kubectl get certificate <cert-name> -n <namespace> -o yaml | grep renewalTime
```

### Certificate Backup

```bash
# Backup all certificates
kubectl get certificates -A -o yaml > backup/certificates-$(date +%Y%m%d).yaml

# Backup certificate secrets
kubectl get secrets -A -l cert-manager.io/certificate-name --o yaml > backup/cert-secrets-$(date +%Y%m%d).yaml
```

### Certificate Cleanup

```bash
# List old certificate requests
kubectl get certificaterequests -A --sort-by='.metadata.creationTimestamp'

# Clean up old certificate requests (optional)
kubectl delete certificaterequests -A -l cert-manager.io/certificate-name=<cert-name>
```

## Security Considerations

### API Token Security

- **Cloudflare API Token**: Stored as SealedSecret
- **Minimum Permissions**: Token has only DNS:Edit permissions for specific zones
- **Secret Rotation**: Regularly rotate API tokens

### Certificate Security

- **TLS 1.2+ Only**: Configure applications to use modern TLS versions
- **Strong Ciphers**: Use secure cipher suites
- **HSTS Headers**: Enable HTTP Strict Transport Security

### Access Control

```bash
# Check RBAC permissions
kubectl auth can-i create certificates --as=system:serviceaccount:cert-manager:cert-manager

# Review cluster roles
kubectl get clusterrole | grep cert-manager
kubectl describe clusterrole cert-manager-controller-certificates
```

## Integration with Other Components

### Traefik Integration

Traefik automatically uses certificates created by cert-manager:

```yaml
# Traefik automatically discovers TLS secrets
annotations:
  traefik.ingress.kubernetes.io/router.tls: "true"
  cert-manager.io/cluster-issuer: letsencrypt-cloudflare
```

### Prometheus Monitoring

Cert-manager exposes metrics for monitoring:

```bash
# Port forward to metrics endpoint
kubectl port-forward -n cert-manager svc/cert-manager 9402:9402

# Key metrics:
# - certmanager_certificate_expiration_timestamp_seconds
# - certmanager_certificate_ready_status
# - certmanager_acme_client_request_count
```

## Configuration Files

### Key Files in Repository

- **`cloudflare-secret.yaml`**: SealedSecret with Cloudflare API token
- **`clusterissuer.yaml`**: Production and staging ClusterIssuers
- **`rbac.yaml`**: Additional RBAC for cross-namespace secret access

### Environment Variables

```bash
# Cloudflare API token (in SealedSecret)
CF_API_TOKEN=<encrypted-token>
```

## Best Practices

1. **Use Staging First**: Test certificates with staging issuer before production
2. **Monitor Expiration**: Set up alerts for certificate expiration
3. **Automate Everything**: Let cert-manager handle all certificate lifecycle
4. **Secure Secrets**: Use SealedSecrets for API tokens
5. **Regular Backups**: Backup certificate configurations
6. **Rate Limit Awareness**: Understand Let's Encrypt rate limits

## Troubleshooting Checklist

- [ ] Check cert-manager pods are running
- [ ] Verify ClusterIssuer is ready
- [ ] Confirm Cloudflare API token is valid
- [ ] Check DNS zone configuration
- [ ] Verify network connectivity
- [ ] Review certificate events and logs
- [ ] Check for rate limiting issues
- [ ] Validate RBAC permissions

## Resources

- **Cert Manager Documentation**: https://cert-manager.io/docs/
- **Let's Encrypt Documentation**: https://letsencrypt.org/docs/
- **Cloudflare API Documentation**: https://developers.cloudflare.com/api/
- **ACME Protocol**: https://tools.ietf.org/html/rfc8555
