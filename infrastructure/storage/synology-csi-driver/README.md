# Synology CSI Driver

Container Storage Interface (CSI) driver for Synology NAS, providing dynamic persistent volume provisioning for Kubernetes workloads.

## Overview

The Synology CSI driver enables Kubernetes to use Synology DiskStation Manager (DSM) as a storage backend, supporting dynamic volume provisioning, snapshot operations, and volume expansion.

## Supported Features

- **Dynamic Provisioning**: Automatic volume creation on Synology NAS
- **Volume Expansion**: Expand existing volumes without downtime
- **Snapshots**: Create and restore volume snapshots
- **Multiple Access Modes**: ReadWriteOnce (RWO) and ReadOnlyMany (ROX)
- **Raw Block Volumes**: Support for raw block device access
- **Volume Cloning**: Create volumes from existing volume snapshots

## Architecture

The driver consists of two main components:

- **Controller Plugin**: Manages volume lifecycle (create, delete, expand, snapshot)
- **Node Plugin**: Handles volume attachment and mounting on worker nodes

## Prerequisites

### Synology NAS Requirements

- **DSM Version**: 7.0 or higher / DSM UC 3.1 or higher
- **Storage Pool**: At least one storage pool configured
- **Volume**: At least one volume created on the storage pool
- **Network**: All Kubernetes nodes must be able to reach the NAS

### Kubernetes Requirements

- **Version**: 1.20 or higher
- **iSCSI Support**: iSCSI initiator tools on all worker nodes
- **Multipath** (optional): Device mapper multipath for redundancy

### Node Prerequisites

Install iSCSI initiator tools on all worker nodes:

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install open-iscsi

# RHEL/CentOS/Fedora
sudo yum install iscsi-initiator-utils

# Enable and start iSCSI service
sudo systemctl enable iscsid
sudo systemctl start iscsid
```

## Installation

### 1. Configure DSM Connection

The driver requires connection details for your Synology NAS. This is configured through a Kubernetes secret containing client information.

Create a `client-info.yml` file:

```yaml
# Example client-info.yml
clients:
  - host: 192.168.1.100 # IP address of your Synology NAS
    port: 5000 # DSM port (5000 for HTTP, 5001 for HTTPS)
    https: false # Use HTTPS connection
    username: admin # DSM admin username
    password: password # DSM admin password
```

### 2. Create Secret

```bash
kubectl create secret generic client-info-secret \
  --from-file=client-info.yml \
  --namespace kube-system
```

### 3. Deploy via Helm

```bash
# Add the chart repository (if not already added)
helm repo add synology-csi https://zebernst.github.io/synology-csi-talos/

# Install the chart
helm install synology-csi synology-csi/synology-csi \
  --namespace kube-system \
  --set clientInfoSecret.name=client-info-secret
```

## Storage Classes

The driver automatically creates a default storage class. You can also create custom storage classes:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: synology-iscsi-ssd
provisioner: csi.san.synology.com
parameters:
  # Optional: specify location (volume path on DSM)
  # If not specified, volumes are created in the default location
  # location: "/volume1/k8s-volumes"

  # Optional: specify file system type
  fsType: ext4

  # Optional: DSM storage pool to use (not required)
  # dsm_volume: "volume1"
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: Immediate
```

## Usage Examples

### Basic Persistent Volume Claim

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: synology-pvc
  namespace: default
spec:
  storageClassName: synology-iscsi-delete
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 10Gi
```

### Database with Persistent Storage

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres-db
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:13
          env:
            - name: POSTGRES_PASSWORD
              value: secretpassword
            - name: POSTGRES_DB
              value: myapp
          volumeMounts:
            - name: postgres-storage
              mountPath: /var/lib/postgresql/data
          ports:
            - containerPort: 5432
      volumes:
        - name: postgres-storage
          persistentVolumeClaim:
            claimName: postgres-pvc
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
spec:
  storageClassName: synology-iscsi-delete
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 20Gi
```

### Volume Snapshots

If you have snapshot CRDs and controller installed:

```yaml
# Create a snapshot
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: my-snapshot
spec:
  volumeSnapshotClassName: synology-snapshotclass
  source:
    persistentVolumeClaimName: synology-pvc
---
# Restore from snapshot
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: restored-pvc
spec:
  storageClassName: synology-iscsi-delete
  dataSource:
    name: my-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 10Gi
```

### Raw Block Volume

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: block-pvc
spec:
  storageClassName: synology-iscsi-delete
  accessModes: [ReadWriteOnce]
  volumeMode: Block
  resources:
    requests:
      storage: 50Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: block-pod
spec:
  containers:
    - name: app
      image: busybox
      command: ["sleep", "3600"]
      volumeDevices:
        - name: block-storage
          devicePath: /dev/xvda
  volumes:
    - name: block-storage
      persistentVolumeClaim:
        claimName: block-pvc
```

## Monitoring and Troubleshooting

### Check Driver Status

```bash
# Verify CSI driver pods
kubectl get pods -n kube-system | grep synology

# Check CSI driver logs
kubectl logs -n kube-system -l app=synology-csi-controller
kubectl logs -n kube-system -l app=synology-csi-node

# Verify storage classes
kubectl get storageclass | grep synology
```

### Volume Operations

```bash
# List persistent volumes
kubectl get pv

# Check PVC status
kubectl get pvc -A

# Describe a specific PVC for events
kubectl describe pvc <pvc-name> -n <namespace>
```

### Common Issues and Solutions

1. **PVC Stuck in Pending State**

   Check the events:

   ```bash
   kubectl describe pvc <pvc-name>
   ```

   Common causes:
   - iSCSI tools not installed on nodes
   - Network connectivity issues to NAS
   - Invalid credentials in client-info secret
   - Insufficient space on Synology volume

2. **Mount Failures**

   ```bash
   # Check node plugin logs
   kubectl logs -n kube-system -l app=synology-csi-node

   # Verify iSCSI connectivity
   sudo iscsiadm -m discovery -t st -p <nas-ip>:3260
   ```

3. **Authentication Errors**

   ```bash
   # Verify client-info secret
   kubectl get secret client-info-secret -n kube-system -o yaml

   # Check controller logs for auth errors
   kubectl logs -n kube-system -l app=synology-csi-controller
   ```

### Performance Tuning

#### iSCSI Multipath (Optional)

For enhanced performance and redundancy, configure multipath:

```bash
# Install multipath tools
sudo apt-get install multipath-tools

# Configure multipath.conf
sudo tee /etc/multipath.conf << EOF
defaults {
    user_friendly_names yes
    find_multipaths yes
}
EOF

# Enable and start multipath
sudo systemctl enable multipathd
sudo systemctl start multipathd
```

#### Network Optimization

- Use dedicated storage networks when possible
- Configure jumbo frames for improved throughput
- Consider link aggregation on the Synology NAS

## Security Considerations

1. **Credential Management**: Store DSM credentials securely using Kubernetes secrets
2. **Network Security**: Implement network policies to restrict access to storage networks
3. **Access Control**: Use RBAC to control who can create/manage storage resources
4. **Encryption**: Consider enabling encryption at rest on Synology volumes
5. **Backup Strategy**: Implement regular backup and snapshot policies

## Volume Expansion

The driver supports online volume expansion:

```bash
# Edit the PVC to increase size
kubectl patch pvc synology-pvc -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'

# Check expansion status
kubectl get pvc synology-pvc -o wide
```

**Note**:

- Volume expansion is only supported for increasing size
- The underlying file system must support online expansion
- Some file systems may require manual expansion commands

## Snapshots

To use volume snapshots, you need:

1. **Snapshot CRDs**: Install volume snapshot CRDs
2. **Snapshot Controller**: Deploy the snapshot controller
3. **Snapshot Class**: Create a VolumeSnapshotClass

Example VolumeSnapshotClass:

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: synology-snapshotclass
driver: csi.san.synology.com
deletionPolicy: Delete
```

## Upgrading

### Version Compatibility

| Driver Version | DSM Version    | Kubernetes Version |
| -------------- | -------------- | ------------------ |
| v1.2.0+        | 7.0+ / UC 3.1+ | 1.20+              |
| v1.1.x         | 6.2+ / UC 3.0+ | 1.17+              |

### Upgrade Process

1. **Backup Configuration**: Save current client-info and storage classes
2. **Test in Non-Production**: Validate new version in test environment
3. **Rolling Update**: Use Helm to upgrade the driver
4. **Verify Operations**: Test volume operations after upgrade

```bash
# Upgrade using Helm
helm upgrade synology-csi synology-csi/synology-csi \
  --namespace kube-system \
  --reuse-values
```

## Best Practices

1. **Resource Planning**: Size volumes appropriately for workload requirements
2. **Monitoring**: Monitor volume usage and performance metrics
3. **Backup Strategy**: Implement regular snapshot and backup procedures
4. **Testing**: Regular disaster recovery testing
5. **Documentation**: Maintain documentation of storage configurations
6. **Capacity Planning**: Monitor DSM storage pool capacity

## Support and Resources

- **Synology CSI GitHub**: [SynologyOpenSource/synology-csi](https://github.com/SynologyOpenSource/synology-csi)
- **Helm Chart**: [zebernst/synology-csi-talos](https://github.com/zebernst/synology-csi-talos)
- **CSI Specification**: [Container Storage Interface](https://github.com/container-storage-interface/spec)

## Troubleshooting Guide

### Diagnostic Commands

```bash
# Check DSM connectivity
ping <nas-ip>
telnet <nas-ip> 5000  # or 5001 for HTTPS

# Verify iSCSI discovery
sudo iscsiadm -m discovery -t st -p <nas-ip>:3260

# Check multipath status (if enabled)
sudo multipath -ll

# View system logs for iSCSI/storage events
sudo journalctl -u iscsid.service
```

### Recovery Procedures

If experiencing persistent issues:

1. **Restart CSI Driver**:

   ```bash
   kubectl rollout restart deployment synology-csi-controller -n kube-system
   kubectl rollout restart daemonset synology-csi-node -n kube-system
   ```

2. **Clear Stale Sessions**:

   ```bash
   # On worker nodes, logout all iSCSI sessions
   sudo iscsiadm -m node -u
   sudo iscsiadm -m node -o delete
   ```

3. **Recreate Client Secret**:
   ```bash
   kubectl delete secret client-info-secret -n kube-system
   kubectl create secret generic client-info-secret --from-file=client-info.yml -n kube-system
   ```

---

**Note**: This Synology CSI driver is managed by FluxCD. Configuration changes should be made through Git.
