#!/bin/bash

# Installation script for mandalor (10.10.4.200) exporters
# This script installs node_exporter and intel-gpu-exporter on the Plex VM

set -e

echo "====================================="
echo "Installing Exporters on Mandalor"
echo "====================================="

# Install node_exporter
echo ""
echo "[1/4] Installing prometheus-node-exporter..."
sudo apt update
sudo apt install -y prometheus-node-exporter

echo "[1/4] Verifying node_exporter is running..."
sudo systemctl status prometheus-node-exporter --no-pager || true
curl -s http://localhost:9100/metrics | grep "node_uname_info" || echo "WARNING: node_exporter metrics not available"

# Install Intel GPU tools
echo ""
echo "[2/4] Installing intel-gpu-tools..."
sudo apt install -y intel-gpu-tools golang-go git

# Verify intel_gpu_top works
echo "[2/4] Testing intel_gpu_top..."
timeout 2 sudo intel_gpu_top -l || echo "intel_gpu_top test completed"

# Build and install intel-gpu-exporter
echo ""
echo "[3/4] Building intel-gpu-exporter..."
cd /opt
if [ -d "intel-gpu-exporter" ]; then
    echo "Removing existing intel-gpu-exporter directory..."
    sudo rm -rf intel-gpu-exporter
fi

sudo git clone https://github.com/timarenz/intel-gpu-exporter.git
cd intel-gpu-exporter
sudo go build -o intel-gpu-exporter

# Create systemd service
echo "[3/4] Creating systemd service for intel-gpu-exporter..."
sudo tee /etc/systemd/system/intel-gpu-exporter.service > /dev/null <<'EOF'
[Unit]
Description=Intel GPU Prometheus Exporter
After=network.target

[Service]
Type=simple
User=root
ExecStart=/opt/intel-gpu-exporter/intel-gpu-exporter
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
echo "[3/4] Enabling and starting intel-gpu-exporter..."
sudo systemctl daemon-reload
sudo systemctl enable intel-gpu-exporter
sudo systemctl start intel-gpu-exporter

# Verify services
echo ""
echo "[4/4] Verifying services..."
echo ""
echo "Node Exporter Status:"
sudo systemctl status prometheus-node-exporter --no-pager | head -10

echo ""
echo "Intel GPU Exporter Status:"
sudo systemctl status intel-gpu-exporter --no-pager | head -10

echo ""
echo "Testing metrics endpoints..."
echo ""
echo "Node Exporter (port 9100):"
curl -s http://localhost:9100/metrics | grep -E "^node_uname_info|^node_cpu_seconds" | head -3

echo ""
echo "Intel GPU Exporter (port 8080):"
curl -s http://localhost:8080/metrics | grep -E "^igpu_" | head -5

echo ""
echo "====================================="
echo "Installation Complete!"
echo "====================================="
echo ""
echo "Next steps:"
echo "1. Commit and push the Kubernetes service configs"
echo "2. Run: flux reconcile kustomization apps --with-source"
echo "3. Verify Prometheus is scraping: kubectl port-forward -n monitoring svc/prometheus-server 9090:9090"
echo "4. Check Grafana dashboard for data"
