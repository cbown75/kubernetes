# Proxmox Exporter

This deploys the Prometheus Proxmox VE Exporter to collect metrics from your Proxmox server.

## Prerequisites

1. **Proxmox API Token**: Create an API token in Proxmox:
   - Navigate to Datacenter → Permissions → API Tokens
   - Add a new token (e.g., `prometheus@pve!monitoring`)
   - Grant it `PVEAuditor` role for read-only access

2. **Sealed Secrets**: Generate the sealed secrets file:
   ```bash
   cd /Users/cbown75/git/kubernetes
   ./scripts/create-proxmox-exporter-secrets.sh
   ```

   You'll be prompted for:
   - Proxmox host (e.g., `korriban.home.cwbtech.net`)
   - Proxmox API user (e.g., `prometheus@pve`)
   - Proxmox API token or password

## Configuration

The exporter is configured via environment variables from the sealed secret:
- `PVE_HOST`: Proxmox server hostname/IP
- `PVE_USER`: Proxmox user (format: `user@realm`)
- `PVE_PASSWORD`: API token or password
- `PVE_VERIFY_SSL`: Set to `false` for self-signed certificates

## Metrics Exposed

The exporter provides metrics with the `pve_` prefix:

### Node Metrics
- `pve_up`: Exporter status
- `pve_node_info`: Node information
- `pve_cpu_usage_ratio`: CPU utilization (0-1)
- `pve_memory_usage_ratio`: Memory utilization (0-1)
- `pve_network_receive_bytes`: Network RX bytes
- `pve_network_transmit_bytes`: Network TX bytes
- `pve_disk_read_bytes`: Disk read bytes
- `pve_disk_write_bytes`: Disk write bytes

### Guest Metrics (VMs/Containers)
- `pve_guest_info`: Guest information (name, type, node)
- `pve_cpu_usage_ratio{type="qemu|lxc"}`: Guest CPU usage
- `pve_memory_usage_ratio{type="qemu|lxc"}`: Guest memory usage
- `pve_onboot_status`: Auto-start status

### Storage Metrics
- `pve_storage_size_bytes`: Total storage size
- `pve_storage_usage_bytes`: Used storage

## Grafana Dashboard

A comprehensive Grafana dashboard is included at:
`apps/grafana/dashboards/proxmox-monitoring.json`

The dashboard includes:
- Cluster overview (status, nodes, VMs, containers)
- CPU and memory usage gauges
- Per-node resource utilization graphs
- Network traffic and disk I/O
- VMs/Containers table with status
- Storage overview

## Deployment

The exporter is deployed via FluxCD GitOps:

```yaml
clusters/korriban/apps/
  └── proxmox-exporter/
      └── kustomization.yaml  # Points to overlay
```

After generating sealed secrets and committing:
```bash
git add .
git commit -m "Add Proxmox monitoring with exporter and dashboard"
git push
```

FluxCD will automatically deploy within 1 minute.

## Verification

Check deployment status:
```bash
# Check pod
kubectl get pods -n monitoring -l app.kubernetes.io/name=proxmox-exporter

# Check logs
kubectl logs -n monitoring -l app.kubernetes.io/name=proxmox-exporter

# Test metrics endpoint
kubectl port-forward -n monitoring svc/proxmox-exporter 9221:9221
curl http://localhost:9221/pve?target=korriban.home.cwbtech.net:8006
```

Check Prometheus is scraping:
```bash
# Query for Proxmox metrics
kubectl port-forward -n monitoring svc/prometheus-server 9090:9090
# Open http://localhost:9090 and query: pve_up
```

## Troubleshooting

### No metrics appearing in Prometheus

1. Check exporter pod logs:
   ```bash
   kubectl logs -n monitoring -l app.kubernetes.io/name=proxmox-exporter
   ```

2. Verify credentials are correct:
   ```bash
   kubectl get secret -n monitoring proxmox-exporter-credentials -o yaml
   ```

3. Test connectivity from pod:
   ```bash
   kubectl exec -n monitoring deployment/proxmox-exporter -- wget -O- http://localhost:9221/pve
   ```

### Authentication errors

- Verify API token has `PVEAuditor` role
- Check user format is correct: `user@realm` (e.g., `prometheus@pve`)
- For API tokens, use format: `user@realm!tokenname` and the token secret as password

### SSL verification issues

Set `PVE_VERIFY_SSL=false` in the deployment if using self-signed certificates.

## References

- [prometheus-pve-exporter](https://github.com/prometheus-pve/prometheus-pve-exporter)
- [Proxmox API Documentation](https://pve.proxmox.com/pve-docs/api-viewer/)
