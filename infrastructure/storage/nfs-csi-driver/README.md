# NFS CSI Driver

Network File System (NFS) Container Storage Interface (CSI) driver for Kubernetes, providing persistent storage backed by NFS servers.

## Overview

This NFS CSI driver enables Kubernetes to use NFS shares as persistent volumes with support for:

- **ReadWriteMany (RWX)** access mode - multiple pods can read/write simultaneously
- **Dynamic provisioning** - automatic subdirectory creation on NFS shares
- **Flexible storage classes** - support for multiple NFS servers and configurations

## Architecture

- **Controller**: Manages volume lifecycle (create, delete, expand)
- **Node Plugin**: Handles volume mounting/unmounting on worker nodes
- **Storage Classes**: Define NFS server endpoints and mount options

## Storage Classes

This deployment includes multiple storage classes for different NFS servers:

### Available Storage Classes

- `nfs-holocron-general` - General purpose storage
- `nfs-holocron-media` - Media/large file storage
- `nfs-holocron-backups` - Backup storage
- `nfs-holocron-plex` - Plex media server storage

### Example Usage

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-nfs-pvc
spec:
  storageClassName: nfs-holocron-general
  accessModes: [ReadWriteMany]
  resources:
    requests:
      storage: 10Gi
```

## Features

### Dynamic Provisioning

The driver automatically creates subdirectories on the NFS share for each PVC:

- Path format: `/{pvc-uuid}`
- Automatic cleanup when PVC is deleted
- Supports multiple concurrent PVCs on same NFS export

### Access Modes

- **ReadWriteMany (RWX)**: Multiple pods can mount the same volume simultaneously
- **ReadOnlyMany (ROX)**: Multiple pods can mount read-only
- **ReadWriteOnce (RWO)**: Single pod exclusive access

### Volume Operations

- **Create**: Provision new NFS subdirectory
- **Delete**: Remove NFS subdirectory
- **Mount**: Mount NFS share in pod containers
- **Unmount**: Clean unmount from containers

## Configuration

### NFS Server Requirements

1. **NFS Server**: Version 3 or 4 supported
2. **Network Access**: Kubernetes nodes must reach NFS server on port 2049
3. **Export Configuration**: Proper NFS exports with appropriate permissions
4. **Client Tools**: `nfs-utils` package on all worker nodes

### Example NFS Server Export

```bash
# /etc/exports on NFS server
/path/to/share *(rw,sync,no_subtree_check,no_root_squash)
```

### Node Prerequisites

Ensure NFS client tools are installed on all worker nodes:

```bash
# Ubuntu/Debian
sudo apt-get install nfs-common

# RHEL/CentOS
sudo yum install nfs-utils

# Alpine (for some container runtimes)
apk add nfs-utils
```

## Usage Examples

### Basic PVC

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: basic-nfs-storage
spec:
  storageClassName: nfs-holocron-general
  accessModes: [ReadWriteMany]
  resources:
    requests:
      storage: 5Gi
```

### Shared Storage Across Pods

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shared-storage-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: shared-app
  template:
    metadata:
      labels:
        app: shared-app
    spec:
      containers:
        - name: app
          image: nginx:latest
          volumeMounts:
            - name: shared-data
              mountPath: /shared
      volumes:
        - name: shared-data
          persistentVolumeClaim:
            claimName: basic-nfs-storage
```

### Media Server Storage

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: plex-media-pvc
spec:
  storageClassName: nfs-holocron-plex
  accessModes: [ReadWriteMany]
  resources:
    requests:
      storage: 100Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: plex-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: plex
  template:
    metadata:
      labels:
        app: plex
    spec:
      containers:
        - name: plex
          image: plexinc/pms-docker:latest
          volumeMounts:
            - name: plex-media
              mountPath: /data
            - name: plex-config
              mountPath: /config
      volumes:
        - name: plex-media
          persistentVolumeClaim:
            claimName: plex-media-pvc
        - name: plex-config
          persistentVolumeClaim:
            claimName: plex-config-pvc
```

## Monitoring and Maintenance

### Check Driver Status

```bash
# Verify CSI driver pods
kubectl get pods -n kube-system -l app=csi-nfs-controller
kubectl get pods -n kube-system -l app=csi-nfs-node

# Check storage classes
kubectl get storageclass | grep nfs

# Monitor PVCs
kubectl get pvc -A | grep nfs
```

### Driver Logs

```bash
# Controller logs
kubectl logs -n kube-system -l app=csi-nfs-controller -c csi-provisioner
kubectl logs -n kube-system -l app=csi-nfs-controller -c nfs

# Node plugin logs
kubectl logs -n kube-system -l app=csi-nfs-node -c nfs
```

## Troubleshooting

### Common Issues

1. **PVC Stuck in Pending**

   ```bash
   # Check events
   kubectl describe pvc <pvc-name>

   # Verify NFS connectivity
   kubectl exec -it <any-pod> -- telnet <nfs-server> 2049
   ```

2. **Mount Failures**

   ```bash
   # Check node logs
   kubectl logs -n kube-system -l app=csi-nfs-node -c nfs

   # Test manual mount
   sudo mount -t nfs4 <server>:<path> /mnt/test
   ```

3. **Permission Issues**

   ```bash
   # Check NFS export permissions
   showmount -e <nfs-server>

   # Verify directory permissions on NFS server
   ls -la /path/to/nfs/export
   ```

### Performance Tuning

#### Mount Options

Optimize mount options in storage class for your workload:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-optimized
provisioner: nfs.csi.k8s.io
parameters:
  server: nfs-server.example.com
  share: /path/to/share
mountOptions:
  - nfsvers=4.1
  - rsize=1048576
  - wsize=1048576
  - hard
  - intr
  - timeo=600
```

#### Network Optimization

- Use dedicated network for NFS traffic
- Configure jumbo frames if supported
- Monitor network latency and throughput

### Recovery Procedures

#### Stale Mount Recovery

```bash
# If pods have stale NFS mounts
kubectl delete pod <pod-name>

# Force unmount if needed (on node)
sudo umount -f /path/to/mount
```

#### Driver Restart

```bash
# Restart CSI driver components
kubectl rollout restart daemonset csi-nfs-node -n kube-system
kubectl rollout restart deployment csi-nfs-controller -n kube-system
```

## Security Considerations

- **Network Security**: Implement firewall rules restricting NFS port access
- **Export Security**: Use specific IP ranges in NFS exports, avoid wildcards
- **Authentication**: Consider Kerberos for enhanced security
- **Encryption**: Use NFSv4 with sec=krb5p for encrypted transfers
- **Access Control**: Implement proper file permissions on NFS server

## Best Practices

1. **Storage Planning**: Size PVCs appropriately for your workload
2. **Backup Strategy**: Regular backups of NFS data
3. **Monitoring**: Monitor NFS server performance and capacity
4. **Network**: Dedicated NFS network for performance
5. **Testing**: Regular disaster recovery testing

## Migration and Upgrades

### Version Compatibility

- CSI Driver: v4.5.0+
- Kubernetes: v1.20+
- NFS Server: v3/v4

### Upgrade Process

1. Review release notes for breaking changes
2. Test in non-production environment
3. Update CSI driver using GitOps workflow
4. Monitor for any mount issues post-upgrade

---

**Note**: This NFS CSI driver is managed by FluxCD. Manual changes will be automatically reverted.
