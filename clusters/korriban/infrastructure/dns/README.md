# DNS Configuration

## Overview

Custom CoreDNS configuration to enable resolution of internal domains within the Kubernetes cluster.

## Configuration

### Domain Forwarding

- `home.cwbtech.net` - Forwarded to router/gateway at `10.10.7.1`
- All other domains - Use default behavior (`/etc/resolv.conf`)

### What this fixes

Allows pods in the cluster to resolve internal domains like:

- `pihole1.home.cwbtech.net`
- `pihole2.home.cwbtech.net`
- `pihole7.home.cwbtech.net`
- `pihole8.home.cwbtech.net`

## Testing DNS Resolution

```bash
# Test from within cluster
kubectl run test-dns --image=busybox --rm -it --restart=Never -- nslookup pihole1.home.cwbtech.net

# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns
```

## Troubleshooting

### DNS not working after applying config

```bash
# Restart CoreDNS to pick up config changes
kubectl rollout restart deployment/coredns -n kube-system

# Verify config was applied
kubectl get configmap coredns -n kube-system -o yaml
```

### Router not resolving home.cwbtech.net

If your router at `10.10.7.1` doesn't know about the domain, you may need to:

1. Configure your router's DNS settings
2. Change the forward IP to your PiHole servers directly
3. Use static IP addresses in application configs instead
