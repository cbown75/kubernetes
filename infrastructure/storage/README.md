# Storage Systems

## Overview

The `korriban` cluster implements a multi-tier storage strategy using Container Storage Interface (CSI) drivers to provide different storage types for various workload requirements.

## Storage Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Storage Tier Strategy                    │
├─────────────────────────────────────────────────────────────┤
│  Performance Tier  │  Shared Tier  │  Backup/Archive Tier  │
│                    │               │                       │
│  Synology iSCSI    │  NFS Shares   │  Synology Snapshots   │
│  - Fast SSDs       │  - ReadMany   │  - Long-term storage  │
│  - Low latency     │  - File share │  - Point-in-time      │
│  - Database/Cache  │  - Logs/Media │  - Disaster recovery  │
└─────────────────────────────────────────────────────────────┘
```

## Storage Classes

### High Performance (Synology iSCSI)

- **synology-holocron-fast**: High-performance SSD storage
- **synology-iscsi-storage-delete**: Standard iSCSI with delete policy

### Shared Storage (NFS)

- **nfs-storage**: Network File System for shared access
- **nfs-fast**: High-performance NFS for shared workloads

## CSI Drivers

### 1. Synology CSI Driver

#### Features

- **iSCSI block storage** from Synology NAS
- **Dynamic provisioning** with automatic LUN creation
- **Volume expansion** support (online resizing)
- **Snapshot capabilities** for backup and recovery
- **High performance** with SSD storage pools

#### Configuration

```yaml
# Storage Classes
synology-holocron-fast:
  provisioner: csi.san.synology.com
  parameters:
    dsm: "192.168.1.100" # Your Synology NAS IP
    fsType: ext4
    location: /volume1
  reclaimPolicy: Retain
  allowVolumeExpansion: true
```

#### Usage Examples

```yaml
# High-performance database storage
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: database-storage
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: synology-holocron-fast
  resources:
    requests:
      storage: 50Gi
```

#### Common Commands

```bash
# Check Synology CSI pods
kubectl get pods -n kube-system | grep synology

# View CSI driver logs
kubectl logs -n kube-system -l app=synology-csi-controller

# Check storage classes
kubectl get sc | grep synology

# List volumes
kubectl get pv | grep synology

# Check volume claims
kubectl get pvc -A
```

### 2. NFS CSI Driver

#### Features

- **Network File System** access for shared storage
- **ReadWriteMany** access mode support
- **Dynamic provisioning** of NFS exports
- **Shared access** across multiple pods
- **File-based storage** ideal for logs, media, configurations

#### Configuration

```yaml
# Storage Classes
nfs-storage:
  provisioner: nfs.csi.k8s.io
  parameters:
    server: "192.168.1.200" # NFS server IP
    share: "/mnt/nfs/kubernetes"
  reclaimPolicy: Retain
  mountOptions:
    - hard
    - nfsvers=4.1
```

#### Usage Examples

```yaml
# Shared log storage
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-logs
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nfs-storage
  resources:
    requests:
      storage: 100Gi
```

#### Common Commands

```bash
# Check NFS CSI pods
kubectl get pods -n nfs-csi-driver

# View NFS driver logs
kubectl logs -n nfs-csi-driver -l app=csi-nfs-controller

# Test NFS connectivity
kubectl run nfs-test --image=busybox --rm -it --restart=Never -- \
  sh -c "mount -t nfs 192.168.1.200:/mnt/nfs/kubernetes /mnt && ls -la /mnt"
```

## Volume Operations

### Creating Persistent Volumes

#### Single Pod Access (RWO)

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-storage
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: synology-holocron-fast
  resources:
    requests:
      storage: 20Gi
```

#### Multi-Pod Shared Access (RWX)

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-storage
  namespace: default
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nfs-storage
  resources:
    requests:
      storage: 50Gi
```

### Volume Expansion

Expand volumes without downtime:

```bash
# Patch PVC to increase size
kubectl patch pvc app-storage -p '{"spec":{"resources":{"requests":{"storage":"40Gi"}}}}'

# Check expansion status
kubectl get pvc app-storage -o wide

# Monitor expansion progress
kubectl describe pvc app-storage
```

### Volume Snapshots

Create point-in-time snapshots:

```yaml
# VolumeSnapshot
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: app-snapshot-$(date +%Y%m%d)
spec:
  volumeSnapshotClassName: synology-snapshotclass
  source:
    persistentVolumeClaimName: app-storage
```

## Troubleshooting

### Storage Driver Issues

#### Check Driver Status

```bash
# Verify CSI drivers are running
kubectl get pods -n kube-system | grep -E "(synology|nfs)"
kubectl get pods -n nfs-csi-driver

# Check CSI driver registration
kubectl get csidriver

# View CSI node info
kubectl get csinodes
```

#### Driver Logs

```bash
# Synology CSI logs
kubectl logs -n kube-system -l app=synology-csi-controller -c csi-provisioner
kubectl logs -n kube-system -l app=synology-csi-node -c csi-plugin

# NFS CSI logs
kubectl logs -n nfs-csi-driver -l app=csi-nfs-controller
kubectl logs -n nfs-csi-driver -l app=csi-nfs-node
```

### Volume Mounting Issues

#### Pod Cannot Mount Volume

```bash
# Check PVC status
kubectl get pvc -n <namespace>
kubectl describe pvc <pvc-name> -n <namespace>

# Check PV binding
kubectl get pv
kubectl describe pv <pv-name>

# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# Check node events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

#### Volume Stuck in Pending

```bash
# Check storage class
kubectl get sc
kubectl describe sc <storage-class>

# Check provisioner logs
kubectl logs -n kube-system -l app=synology-csi-controller
kubectl logs -n nfs-csi-driver -l app=csi-nfs-controller

# Verify storage backend connectivity
kubectl exec -n kube-system <csi-controller-pod> -- ping <storage-server>
```

### Performance Issues

#### Storage Performance Testing

```bash
# Create test pod with volume
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: storage-test
spec:
  containers:
  - name: test
    image: ubuntu:20.04
    command: ["sleep", "3600"]
    volumeMounts:
    - name: test-volume
      mountPath: /test
  volumes:
  - name: test-volume
    persistentVolumeClaim:
      claimName: test-storage
EOF

# Run performance tests
kubectl exec storage-test -- dd if=/dev/zero of=/test/testfile bs=1M count=1000
kubectl exec storage-test -- sync
kubectl exec storage-test -- dd if=/test/testfile of=/dev/null bs=1M count=1000
```

#### Monitor Storage Metrics

```bash
# Check disk usage
kubectl exec <pod> -- df -h /data

# Check I/O statistics
kubectl exec <pod> -- iostat -x 1 5

# Monitor volume usage
kubectl get pvc -A -o custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace,SIZE:.spec.resources.requests.storage,USED:.status.capacity.storage
```

### Network Storage Connectivity

#### NFS Connectivity

```bash
# Test NFS mount
kubectl run nfs-test --image=busybox --rm -it --restart=Never -- \
  sh -c "mount -t nfs <nfs-server>:<path> /mnt && ls -la /mnt"

# Check NFS exports
showmount -e <nfs-server>

# Test network connectivity
kubectl run network-test --image=busybox --rm -it --restart=Never -- \
  sh -c "nc -zv <nfs-server> 2049"
```

#### iSCSI Connectivity (Synology)

```bash
# Check iSCSI discovery
kubectl exec -n kube-system <synology-node-pod> -- \
  iscsiadm -m discovery -t st -p <synology-ip>:3260

# Check iSCSI sessions
kubectl exec -n kube-system <synology-node-pod> -- \
  iscsiadm -m session

# Test Synology API connectivity
kubectl run synology-test --image=busybox --rm -it --restart=Never -- \
  sh -c "nc -zv <synology-ip> 5000"
```

## Storage Monitoring

### Metrics Collection

Storage metrics are collected by Prometheus:

```bash
# Access Prometheus dashboard
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Key storage metrics:
# - kubelet_volume_stats_capacity_bytes
# - kubelet_volume_stats_used_bytes
# - kubelet_volume_stats_available_bytes
```

### Storage Alerts

Monitor storage usage and health:

```yaml
# Example: Storage space alert
- alert: StorageSpaceLow
  expr: (kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes) > 0.8
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Storage space low on {{ $labels.persistentvolumeclaim }}"
```

### Health Checks

Regular storage health monitoring:

```bash
# Check all PVC status
kubectl get pvc -A --sort-by='.metadata.creationTimestamp'

# Monitor volume capacity
kubectl get pv -o custom-columns=NAME:.metadata.name,CAPACITY:.spec.capacity.storage,STATUS:.status.phase,CLAIM:.spec.claimRef.name

# Check storage class health
kubectl get sc -o custom-columns=NAME:.metadata.name,PROVISIONER:.provisioner,AGE:.metadata.creationTimestamp
```

## Backup and Recovery

### Volume Snapshots

Automated backup strategy:

```yaml
# Daily snapshot CronJob
apiVersion: batch/v1
kind: CronJob
metadata:
  name: daily-snapshots
spec:
  schedule: "0 2 * * *" # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: snapshot
              image: bitnami/kubectl
              command:
                - /bin/sh
                - -c
                - |
                  kubectl create -f - <<EOF
                  apiVersion: snapshot.storage.k8s.io/v1
                  kind: VolumeSnapshot
                  metadata:
                    name: daily-$(date +%Y%m%d)
                  spec:
                    volumeSnapshotClassName: synology-snapshotclass
                    source:
                      persistentVolumeClaimName: app-storage
                  EOF
          restartPolicy: OnFailure
```

### Disaster Recovery

Recovery procedures:

```bash
# Restore from snapshot
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: restored-storage
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: synology-holocron-fast
  dataSource:
    name: daily-20241201
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  resources:
    requests:
      storage: 50Gi
EOF
```

## Best Practices

### Storage Strategy

1. **Choose appropriate storage class** for workload requirements
2. **Use RWO for databases** and single-pod applications
3. **Use RWX for shared data** like logs or media
4. **Implement regular backups** with volume snapshots
5. **Monitor storage usage** and set up alerts

### Performance Optimization

1. **Use SSD storage** for high-performance workloads
2. **Separate OS and data** on different volumes
3. **Configure appropriate filesystem** (ext4 for most cases)
4. **Monitor I/O patterns** and adjust accordingly
5. **Use local storage** for temporary/cache data

### Security

1. **Encrypt data at rest** on storage backend
2. **Use network encryption** for storage traffic
3. **Implement access controls** with RBAC
4. **Regular security updates** for CSI drivers
5. **Audit storage access** patterns

## Storage Migration

### Migrating Between Storage Classes

```bash
# Create new PVC with target storage class
kubectl apply -f new-storage-pvc.yaml

# Copy data between volumes
kubectl run data-migration --image=busybox --rm -it --restart=Never -- \
  sh -c "cp -r /old-volume/* /new-volume/"

# Update application to use new PVC
kubectl patch deployment app --patch '{"spec":{"template":{"spec":{"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"new-storage"}}]}}}}'
```

## Resources

- **Kubernetes CSI Documentation**: https://kubernetes-csi.github.io/docs/
- **Synology CSI Driver**: https://github.com/SynologyOpenSource/synology-csi
- **NFS CSI Driver**: https://github.com/kubernetes-csi/csi-driver-nfs
- **Volume Snapshots**: https://kubernetes.io/docs/concepts/storage/volume-snapshots/
