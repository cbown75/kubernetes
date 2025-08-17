# NFS CSI Driver

This Helm chart deploys the official NFS CSI driver (`nfs.csi.k8s.io`) for Kubernetes, enabling dynamic provisioning of persistent volumes from NFS servers.

## Features

- **Dynamic Provisioning**: Automatically creates subdirectories on NFS server for each PVC
- **Multiple Access Modes**: Supports ReadWriteMany, ReadWriteOnce, and ReadOnlyMany
- **Volume Expansion**: Supports online volume expansion
- **Snapshots**: Supports volume snapshots (if snapshot controller is installed)
- **Vendor Agnostic**: Works with any NFS server (Synology, FreeNAS, standard Linux NFS, etc.)

## Prerequisites

1. **NFS Server**: A working NFS server with configured exports
2. **Network Connectivity**: All Kubernetes nodes must be able to connect to the NFS server
3. **NFS Client**: NFS client utilities installed on all nodes (usually pre-installed on most distributions)

## Configuration

### NFS Server Setup

Before deploying, ensure your NFS server is properly configured:

#### Synology NAS Example

1. Open Control Panel → File Services → NFS
2. Enable NFS service with NFSv4.1
3. Create a shared folder (e.g., `/volume1/kubernetes`)
4. Configure NFS permissions for your Kubernetes subnet

#### Linux NFS Server Example

```bash
# Install NFS server
sudo apt-get install nfs-kernel-server

# Create export directory
sudo mkdir -p /srv/nfs/kubernetes
sudo chown nobody:nogroup /srv/nfs/kubernetes

# Configure exports
echo '/srv/nfs/kubernetes 10.0.0.0/24(rw,sync,no_subtree_check,no_root_squash)' | sudo tee -a /etc/exports

# Apply exports
sudo exportfs -a
sudo systemctl restart nfs-kernel-server
```

### Chart Configuration

The chart supports multiple NFS servers with multiple shares each. Update `clusters/korriban/infrastructure/storage/nfs-csi/release.yaml`:

```yaml
values:
  nfsServers:
    holocron:
      host: "holocron.home.cwbtech.net"
      shares:
        fast: "/volume1/k8s-fast"
        general: "/volume1/k8s-general"
        backup: "/volume1/k8s-backup"
    sith:
      host: "sith.home.cwbtech.net"
      shares:
        fast: "/volume1/k8s-fast"
        general: "/volume1/k8s-general"
        backup: "/volume1/k8s-backup"
```

## Deployment

1. **Update NFS server details** in `clusters/korriban/infrastructure/storage/nfs-csi/release.yaml`
2. **Commit to git** and push changes
3. **FluxCD will automatically deploy** the driver

## Storage Classes

The chart creates six storage classes across two NFS servers:

### Holocron NAS (holocron.home.cwbtech.net)

- **nfs-holocron-fast** (Default): Fast storage, Delete policy
- **nfs-holocron-general**: General storage, Retain policy
- **nfs-holocron-backup**: Backup storage, Retain policy

### Sith NAS (sith.home.cwbtech.net)

- **nfs-sith-fast**: Fast storage, Delete policy
- **nfs-sith-general**: General storage, Retain policy
- **nfs-sith-backup**: Backup storage, Retain policy

All storage classes support:

- **Access Modes**: ReadWriteMany, ReadWriteOnce, ReadOnlyMany
- **Volume Expansion**: Enabled
- **Mount Options**: hard, nfsvers=4.1, intr

## Usage Examples

### Fast Storage (Temporary/Cache)

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-cache-pvc
spec:
  storageClassName: nfs-holocron-fast # or nfs-sith-fast
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 5Gi
```

### General Storage (Persistent Data)

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data-pvc
spec:
  storageClassName: nfs-holocron-general # or nfs-sith-general
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
```

### Backup Storage (Long-term Retention)

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-backup-pvc
spec:
  storageClassName: nfs-sith-backup # or nfs-holocron-backup
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 50Gi
```

### Application with Multiple Storage Tiers

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-cache
spec:
  storageClassName: nfs-holocron-fast
  accessModes: [ReadWriteMany]
  resources:
    requests:
      storage: 2Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data
spec:
  storageClassName: nfs-holocron-general
  accessModes: [ReadWriteMany]
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: multi-tier-app
spec:
  containers:
    - name: app
      image: nginx:latest
      volumeMounts:
        - name: cache
          mountPath: /cache
        - name: data
          mountPath: /data
  volumes:
    - name: cache
      persistentVolumeClaim:
        claimName: app-cache
    - name: data
      persistentVolumeClaim:
        claimName: app-data
```

### Load-Balanced App Across Multiple NAS

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: distributed-app
spec:
  replicas: 4
  selector:
    matchLabels:
      app: distributed-app
  template:
    metadata:
      labels:
        app: distributed-app
    spec:
      containers:
        - name: app
          image: nginx:latest
          volumeMounts:
            - name: shared-content
              mountPath: /usr/share/nginx/html
      volumes:
        - name: shared-content
          persistentVolumeClaim:
            claimName: shared-content-pvc
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-content-pvc
spec:
  storageClassName: nfs-holocron-general # All replicas share same storage
  accessModes: [ReadWriteMany]
  resources:
    requests:
      storage: 5Gi
```

## Testing

Test examples are available in `examples/test-pod.yaml`:

```bash
# Apply test resources
kubectl apply -f infrastructure/storage/nfs-csi-driver/examples/test-pod.yaml

# Check PVC status
kubectl get pvc

# Check pod logs
kubectl logs test-nfs-pod

# Verify files on NFS server
# Files should appear in your NFS share under subdirectories
```

## Troubleshooting

### Common Issues

1. **PVC Stuck in Pending**
   - Check NFS server connectivity: `telnet <nfs-server> 2049`
   - Verify NFS exports: `showmount -e <nfs-server>`
   - Check driver logs: `kubectl logs -n kube-system -l app=csi-nfs-controller`

2. **Mount Failures**
   - Verify NFS client tools: `which mount.nfs`
   - Check node logs: `kubectl logs -n kube-system -l app=csi-nfs-node`
   - Test manual mount: `sudo mount -t nfs4 <server>:<share> /mnt/test`

3. **Permission Issues**
   - NFS export permissions (check `no_root_squash` if needed)
   - Directory permissions on NFS server
   - Pod security contexts and fsGroup settings

### Useful Commands

```bash
# View all NFS storage classes
kubectl get storageclass -l app.kubernetes.io/name=nfs-csi-driver

# Check specific NAS connectivity
kubectl run nfs-test --image=busybox --rm -it -- nslookup holocron.home.cwbtech.net
kubectl run nfs-test --image=busybox --rm -it -- nslookup sith.home.cwbtech.net

# Test NFS mount manually
kubectl run nfs-test --image=busybox --rm -it -- mount -t nfs4 holocron.home.cwbtech.net:/volume1/k8s-fast /mnt
```

## Benefits over In-Tree NFS

- **Future-Proof**: CSI is the standard, in-tree drivers are deprecated
- **Better Maintenance**: Independent release cycle from Kubernetes
- **Enhanced Features**: Snapshots, volume expansion, better error handling
- **Improved Security**: Reduced attack surface in Kubernetes core

## Mount Options

The chart uses optimized mount options by default:

- `hard`: Hard mount (operations wait if server unavailable)
- `nfsvers=4.1`: Use NFSv4.1 for better performance and security
- `intr`: Allow interruption of NFS operations

Additional options can be added in the values file:

```yaml
storageClasses:
  nfsCsi:
    mountOptions:
      - hard
      - nfsvers=4.1
      - intr
      - rsize=1048576 # 1MB read size
      - wsize=1048576 # 1MB write size
      - timeo=14 # Timeout value
      - retrans=2 # Number of retries
```

## Security Considerations

- Ensure proper NFS export security
- Network security between Kubernetes cluster and NFS server
- Consider using NFSv4 with Kerberos for production environments
- Review and adjust mount options for your security requirements
