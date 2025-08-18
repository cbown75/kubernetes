# MetalLB Load Balancer for Korriban Cluster

## Overview

MetalLB provides a network load balancer implementation for bare metal Kubernetes clusters, using Layer 2 (ARP/NDP) mode to assign real IPs to services. Unlike cloud providers, bare metal clusters don't have a built-in LoadBalancer implementation - MetalLB fills this gap.

## How MetalLB Works

### IP Address Management

MetalLB **does not use DHCP**. Instead:

1. **Static IP Pool**: You define a range of IPs that MetalLB can use (10.10.7.200-250)
2. **Self-Managed**: MetalLB tracks which IPs are assigned to which services
3. **ARP Announcements**: When a service needs an IP, MetalLB:
   - Picks an unused IP from the pool
   - Announces via ARP: "I am 10.10.7.200" from one of the nodes
   - Routes traffic to the correct service

### Traffic Flow

```
External Client
      ↓
Router (10.10.7.1)
      ↓
ARP: "Who has 10.10.7.200?"
      ↓
MetalLB Speaker: "I do!" (from node 10.10.7.5)
      ↓
Traffic → Node (10.10.7.5)
      ↓
kube-proxy → Traefik Pod(s)
      ↓
Your Service
```

## Network Requirements

### Router Configuration

⚠️ **Important**: You must configure your router to prevent IP conflicts:

1. **Reserve IP Range in DHCP**

   - Access your router's DHCP settings
   - Reserve/exclude `10.10.7.200` through `10.10.7.250`
   - This prevents the router from assigning these IPs to other devices

2. **Example Router Configurations**:

   **UniFi/Ubiquiti**:

   ```
   Settings → Networks → LAN → DHCP
   Add DHCP Exclusion: 10.10.7.200-10.10.7.250
   ```

   **pfSense**:

   ```
   Services → DHCP Server → LAN
   Add IP Range Exclusion: 10.10.7.200-10.10.7.250
   ```

   **Generic Router**:

   ```
   DHCP Settings → Reserved/Excluded IPs
   Start: 10.10.7.200
   End: 10.10.7.250
   ```

3. **DNS Configuration** (optional but recommended):
   - Add static DNS entries pointing to MetalLB IP
   - Example: `*.home.cwbtech.net → 10.10.7.200`

### Firewall Rules

For **internal access only**: No firewall changes needed

For **external access** (from internet):

- Port forward 80 → 10.10.7.200:80
- Port forward 443 → 10.10.7.200:443

## IP Address Allocation

### Default Pool (10.10.7.200-250)

- **Purpose**: Public-facing services
- **Auto-assign**: Yes
- **Primary user**: Traefik (will get first IP: 10.10.7.200)
- **Available IPs**: 51 addresses

### Internal Pool (10.10.7.100-150)

- **Purpose**: Internal-only services
- **Auto-assign**: No (requires explicit annotation)
- **Use case**: Databases, internal APIs
- **Available IPs**: 51 addresses

### Current IP Assignments

| IP Address      | Service                | Namespace      | Purpose                 |
| --------------- | ---------------------- | -------------- | ----------------------- |
| 10.10.7.200     | traefik-system-traefik | traefik-system | Main ingress controller |
| 10.10.7.201-250 | _Available_            | -              | Future services         |

## Configuration

### IPAddressPool Configuration

```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default
  namespace: metallb-system
spec:
  addresses:
    - 10.10.7.200-10.10.7.250 # 51 IPs for LoadBalancer services
  autoAssign: true # Automatically assign IPs
  avoidBuggyIPs: true # Skip .0 and .255 if included
```

### L2Advertisement Configuration

```yaml
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
    - default
    - internal
  # All nodes can advertise (no restrictions)
```

## Usage Examples

### Basic LoadBalancer Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
  namespace: default
spec:
  type: LoadBalancer
  ports:
    - port: 80
      targetPort: 8080
  selector:
    app: my-app
# MetalLB will automatically assign an IP like 10.10.7.201
```

### Request Specific IP

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
  namespace: default
  annotations:
    metallb.universe.tf/loadBalancerIPs: "10.10.7.205"
spec:
  type: LoadBalancer
  ports:
    - port: 80
      targetPort: 8080
  selector:
    app: my-app
```

### Use Internal Pool

```yaml
apiVersion: v1
kind: Service
metadata:
  name: internal-db
  namespace: default
  labels:
    metallb-pool: internal
  annotations:
    metallb.universe.tf/address-pool: internal
spec:
  type: LoadBalancer
  ports:
    - port: 5432
      targetPort: 5432
  selector:
    app: postgresql
```

## Monitoring & Troubleshooting

### Check MetalLB Status

```bash
# Verify MetalLB pods are running
kubectl get pods -n metallb-system

# Expected output:
# NAME                          READY   STATUS    RESTARTS   AGE
# metallb-controller-xxx        1/1     Running   0          5m
# metallb-speaker-xxx           1/1     Running   0          5m
# metallb-speaker-yyy           1/1     Running   0          5m
```

### View IP Assignments

```bash
# See all LoadBalancer services and their IPs
kubectl get svc -A | grep LoadBalancer

# Check IP pool usage
kubectl get ipaddresspool -n metallb-system -o wide

# Detailed pool information
kubectl describe ipaddresspool default -n metallb-system
```

### Test Connectivity

```bash
# From another machine on the network
ping 10.10.7.200

# Check ARP entries
arp -a | grep 10.10.7.200

# Test HTTP/HTTPS
curl -v http://10.10.7.200
curl -v https://10.10.7.200
```

### Common Issues & Solutions

#### Issue: Service Stuck in Pending

```bash
kubectl describe svc <service-name>
# Look for events like "no available IPs"
```

**Solutions**:

- Check if IP pool is exhausted
- Verify MetalLB pods are running
- Check controller logs: `kubectl logs -n metallb-system deployment/metallb-controller`

#### Issue: IP Not Reachable

**Check Layer 2 connectivity**:

```bash
# From another host on the network
arping -I eth0 10.10.7.200
```

**Solutions**:

- Verify all nodes are on same L2 network
- Check speaker logs: `kubectl logs -n metallb-system daemonset/metallb-speaker`
- Ensure no IP conflicts with other devices

#### Issue: Slow Failover

When a node fails, it takes 10-20 seconds for the IP to move to another node. This is **normal for L2 mode** due to:

- ARP cache timeout (usually 10-20 seconds)
- Gratuitous ARP propagation time

**To force faster failover**:

```bash
# Clear ARP cache on clients
sudo arp -d 10.10.7.200
```

## Maintenance

### Expand IP Pool

Edit `config.yaml` and apply:

```yaml
addresses:
  - 10.10.7.200-10.10.7.250 # Original
  - 10.10.7.251-10.10.7.254 # Add 4 more IPs
```

```bash
kubectl apply -f clusters/korriban/infrastructure/metallb/config.yaml
```

### Monitor IP Pool Usage

Set up alerts when pool usage exceeds 80%:

```yaml
alert: MetalLBIPPoolExhaustion
expr: |
  (metallb_allocator_addresses_in_use_total / metallb_allocator_addresses_total) > 0.8
for: 5m
annotations:
  summary: "MetalLB IP pool {{ $labels.pool }} is {{ $value | humanizePercentage }} full"
```

### Backup IP Assignments

```bash
# Export current assignments
kubectl get svc -A -o json | jq '.items[] |
  select(.spec.type=="LoadBalancer") |
  {name: .metadata.name, namespace: .metadata.namespace, ip: .status.loadBalancer.ingress[0].ip}'
```

## Best Practices

1. **IP Planning**

   - Document all IP assignments
   - Reserve 20% of pool for growth
   - Use separate pools for prod/dev

2. **Network Hygiene**

   - Always reserve IPs in DHCP
   - Monitor for IP conflicts
   - Document in router config

3. **High Availability**

   - Run multiple replicas of critical services
   - Spread across nodes with anti-affinity
   - Test failover scenarios

4. **Security**
   - Use network policies to restrict traffic
   - Enable metrics authentication
   - Regular security updates

## Architecture Decisions

### Why L2 Mode?

- **Simplicity**: No BGP router configuration needed
- **Compatibility**: Works with any network hardware
- **Home lab friendly**: Perfect for small clusters

### Why These IP Ranges?

- **10.10.7.200-250**: High numbers avoid conflicts with DHCP typical ranges
- **10.10.7.100-150**: Separate internal range for security isolation
- **Gap from node IPs**: Nodes use .2-.8, services use .100+

### Limitations

- **Single node bottleneck**: All traffic for an IP goes through one node
- **No true load balancing**: L2 mode provides failover, not load distribution
- **Same L2 segment required**: All nodes must be on the same network

## Integration with GitOps

This MetalLB deployment is managed by FluxCD:

```yaml
# Deployment hierarchy
flux-system
├── metallb (HelmRelease)
│   └── Creates controller + speaker pods
└── metallb-config (Kustomization)
└── Creates IPAddressPool + L2Advertisement
```

Any changes should be made via Git:

1. Edit files in `clusters/korriban/infrastructure/metallb/`
2. Commit and push
3. FluxCD applies changes automatically

## References

- [MetalLB Documentation](https://metallb.universe.tf/)
- [L2 Mode Concepts](https://metallb.universe.tf/concepts/layer2/)
- [Configuration Guide](https://metallb.universe.tf/configuration/)
- [Troubleshooting Guide](https://metallb.universe.tf/troubleshooting/)

## Support

For issues specific to this deployment:

1. Check MetalLB pods: `kubectl get pods -n metallb-system`
2. Review controller logs: `kubectl logs -n metallb-system deployment/metallb-controller`
3. Review speaker logs: `kubectl logs -n metallb-system daemonset/metallb-speaker`
4. Check IP assignments: `kubectl get svc -A | grep LoadBalancer`
