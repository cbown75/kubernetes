# NFS CSI Driver for Kubernetes

## Overview

This Helm chart deploys the NFS CSI Driver for Kubernetes with configurations optimized for Synology NAS systems. It provides persistent storage using NFS shares from multiple Synology NAS devices with high-performance 50Gb network connections.

## Architecture

- **Primary NAS**: Holocron (`holocron.home.cwbtech.net`) - General Kubernetes workloads
- **Secondary NAS**: Sith (`sith.home.cwbtech.net`) - Secondary storage and future media workloads
- **High Performance**: Optimized for 50Gb fiber connections with large block sizes
- **Multi-Tier Storage**: Fast, general, and backup storage classes

## Storage Classes

### Holocron NAS (Primary)

- `nfs-holocron-fast` (default) - High-performance storage using SSD pool
- `nfs-holocron` - General purpose storage
- `nfs-holocron-backup` - Backup and archive storage

### Sith NAS (Secondary)

- `nfs-sith-fast` - High-performance secondary storage
- `nfs-sith` - General purpose secondary storage
- `nfs-sith-backup` - Secondary backup storage
- `nfs-sith-media` - Media storage for arr stack and Plex (disabled by default)

## Prerequisites

### NFS Shares Required

Create the following NFS shares on both NAS systems:

**Holocron NAS:**

- `/volume1/kubernetes`
- `/volume1/kubernetes-fast`
- `/volume1/kubernetes-backup`

**Sith NAS:**

- `/volume1/kubernetes`
- `/volume1/kubernetes-fast`
- `/volume1/kubernetes-backup`

### NFS Configuration

For each share, configure:

- **Privilege**: Read/Write
- **Squash**: Map all users to admin
- **Security**: sys
- **Enable asynchronous**: ✅ (critical for 50Gb performance)
- **Enable NFSv4**: ✅
- **Allow connections from**: Your Kubernetes subnet

## Installation

This chart is deployed automatically via FluxCD. The deployment is managed by:

- `clusters/korriban/infrastructure/storage/release.yaml`
- `clusters/korriban/infrastructure/storage/kustomization.yaml`

### Manual Installation (for testing)

```bash
# Install the chart directly
helm install nfs-csi-driver . -n nfs-csi-driver --create-namespace

# Upgrade
helm upgrade nfs-csi-driver . -n nfs-csi-driver
```

## Configuration

### Key Values

```yaml
# NAS servers
nas:
  holocron:
    server: holocron.home.cwbtech.net
  sith:
    server: sith.home.cwbtech.net

# Default storage class
storageClasses:
  defaultClass: nfs-holocron-fast

# Performance optimization for 50Gb connection
mountOptions:
  fast:
    - nfsvers=4.1
    - rsize=1048576 # 1MB blocks
    - wsize=1048576 # 1MB blocks
    - fsc # Local caching
```

### Enabling Media Storage

To enable media storage for arr stack and Plex:

```yaml
storageClasses:
  sith:
    media:
      enabled: true
```

First create the media NFS share: `/volume1/media` on Sith NAS.

## Testing

### Validate Storage Classes

```bash
# Apply test manifests
kubectl apply -f ../../clusters/korriban/tests/storage/test-storage-classes.yaml

# Check test pods
kubectl logs -n storage-test holocron-test-pod
kubectl logs -n storage-test sith-test-pod

# List all storage classes
kubectl get storageclass

# Clean up tests
kubectl delete -f ../../clusters/korriban/tests/storage/test-storage-classes.yaml
```

### Create Test PVC

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: nfs-holocron-fast
```

## Performance Tuning

### Mount Options Explained

- `nfsvers=4.1` - Use NFSv4.1 for better performance and features
- `rsize=1048576` - 1MB read size for high-bandwidth connections
- `wsize=1048576` - 1MB write size for high-bandwidth connections
- `hard` - Hard mount (don't give up on network issues)
- `intr` - Allow interruption of NFS calls
- `timeo=600` - 60 second timeout
- `fsc` - Enable local caching for frequently accessed files

### For Different Workloads

- **Fast Storage**: Large blocks (1MB), caching enabled
- **General Storage**: Large blocks (1MB), no caching
- **Backup Storage**: Smaller blocks (64KB) for sequential access

## Troubleshooting

### Check CSI Driver Status

```bash
# Check CSI driver pods
kubectl get pods -n nfs-csi-driver

# Check CSI driver logs
kubectl logs -n nfs-csi-driver -l app.kubernetes.io/component=controller
kubectl logs -n nfs-csi-driver -l app.kubernetes.io/component=node

# Check storage classes
kubectl get storageclass
kubectl describe storageclass nfs-holocron-fast
```

### Common Issues

1. **PVC Stuck in Pending**
   - Check NFS share accessibility from nodes
   - Verify NFS server hostname resolution
   - Check CSI driver pod logs

2. **Mount Failures**
   - Ensure NFS shares exist and are properly configured
   - Check network connectivity between nodes and NAS
   - Verify NFS service is running on Synology

3. **Performance Issues**
   - Check mount options are applied correctly
   - Verify asynchronous mode is enabled on NAS
   - Monitor network utilization

### Debug Commands

```bash
# Test NFS connectivity from a node
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
# Inside the pod:
# mount -t nfs4 holocron.home.cwbtech.net:/volume1/kubernetes-fast /mnt

# Check PVC events
kubectl describe pvc <pvc-name>

# Check PV details
kubectl get pv
kubectl describe pv <pv-name>
```

## Security

### Network Security

- Restrict NFS access to Kubernetes subnet only
- Use VLANs to isolate storage traffic
- Enable firewall rules on NAS systems

### Pod Security

- CSI driver runs with minimal required privileges
- Uses non-root security contexts where possible
- Follows Kubernetes security best practices

## Maintenance

### Upgrading the Chart

1. Update image tags in `values.yaml`
2. Test in staging environment
3. FluxCD will automatically apply changes

### Adding New Storage Classes

1. Create new NFS share on NAS
2. Add storage class configuration to `values.yaml`
3. Commit changes for FluxCD deployment

### Monitoring

Storage metrics are available through:

- CSI driver metrics endpoint
- Kubernetes storage metrics
- Synology NAS monitoring tools

## References

- [NFS CSI Driver Documentation](https://github.com/kubernetes-csi/csi-driver-nfs)
- [Kubernetes Storage Documentation](https://kubernetes.io/docs/concepts/storage/)
- [Synology NFS Setup Guide](https://kb.synology.com/en-us/DSM/help/DSM/AdminCenter/file_share_nfs)
