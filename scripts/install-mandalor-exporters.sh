#!/bin/bash

# Installation script for mandalor plex monitoring
# Installs timothystewart6/prometheus-plex-exporter and intel_gpu_top exporter

set -e

echo "======================================"
echo "Installing Exporters for Plex Dashboard"
echo "======================================"
echo ""
echo "This will install:"
echo "  1. timothystewart6/prometheus-plex-exporter (replaces sfragata)"
echo "  2. intel_gpu_top exporter for GPU metrics"
echo ""

# Step 1: Stop and remove old exporter
echo "[1/5] Removing old sfragata plex-exporter..."
sudo systemctl stop plex-exporter 2>/dev/null || true
sudo systemctl disable plex-exporter 2>/dev/null || true
sudo rm -f /usr/local/bin/plex_exporter
sudo rm -f /etc/systemd/system/plex-exporter.service
sudo systemctl daemon-reload
echo "  ✓ Old exporter removed"

# Step 2: Install dependencies
echo ""
echo "[2/5] Installing dependencies..."
sudo apt update
sudo apt install -y golang-go git intel-gpu-tools
echo "  ✓ Dependencies installed"

# Step 3: Build timothystewart6 plex exporter
echo ""
echo "[3/5] Building timothystewart6/prometheus-plex-exporter..."
cd /opt
sudo rm -rf prometheus-plex-exporter 2>/dev/null || true
sudo git clone https://github.com/timothystewart6/prometheus-plex-exporter.git
cd prometheus-plex-exporter

# Check for the actual main.go location
if [ -f "cmd/prometheus-plex-exporter/main.go" ]; then
    sudo go build -o plex-exporter ./cmd/prometheus-plex-exporter
elif [ -f "cmd/prom-plex-exporter/main.go" ]; then
    sudo go build -o plex-exporter ./cmd/prom-plex-exporter
elif [ -f "main.go" ]; then
    sudo go build -o plex-exporter .
else
    echo "Error: Cannot find main.go"
    ls -la
    ls -la cmd/ 2>/dev/null || true
    exit 1
fi
echo "  ✓ Plex exporter built at /opt/prometheus-plex-exporter/plex-exporter"

# Step 4: Create systemd service for plex exporter
echo ""
echo "[4/5] Creating systemd service for plex-exporter..."
sudo tee /etc/systemd/system/plex-exporter.service > /dev/null <<'EOF'
[Unit]
Description=Plex Exporter for Prometheus (TechnoTim)
After=network.target plexmediaserver.service
Wants=plexmediaserver.service

[Service]
Type=simple
User=cbown75
Group=cbown75
Environment="PLEX_SERVER=http://localhost:32400"
Environment="PLEX_TOKEN=rpJMidmyH-xCJWH4Rdgh"
Environment="PORT=9000"
ExecStart=/opt/prometheus-plex-exporter/plex-exporter
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable plex-exporter
sudo systemctl start plex-exporter
echo "  ✓ Plex exporter service running on port 9000"

# Step 5: Install intel_gpu_top exporter
echo ""
echo "[5/5] Installing intel_gpu_top exporter..."

# Create Python virtual environment
cd /opt
sudo rm -rf intel-gpu-exporter 2>/dev/null || true
sudo mkdir -p intel-gpu-exporter
cd intel-gpu-exporter

# Create the exporter script
sudo tee intel_gpu_exporter.py > /dev/null <<'PYTHON_EOF'
#!/usr/bin/env python3
import subprocess
import re
import time
from prometheus_client import start_http_server, Gauge

# Create Prometheus metrics
gpu_freq = Gauge('igpu_frequency_actual', 'Intel GPU actual frequency in MHz')
gpu_video_busy = Gauge('igpu_engines_video_0_busy', 'Intel GPU video engine utilization percentage')
gpu_render_busy = Gauge('igpu_engines_render_3d_0_busy', 'Intel GPU render engine utilization percentage')
gpu_compute_busy = Gauge('igpu_engines_compute_0_busy', 'Intel GPU compute engine utilization percentage')
gpu_rc6 = Gauge('igpu_rc6', 'Intel GPU RC6 power state percentage')
gpu_bw_read = Gauge('igpu_imc_bandwidth_reads', 'Intel GPU memory bandwidth reads in MB/s')
gpu_bw_write = Gauge('igpu_imc_bandwidth_writes', 'Intel GPU memory bandwidth writes in MB/s')

def parse_intel_gpu_top():
    try:
        # Run intel_gpu_top for 1 second and capture output
        result = subprocess.run(['sudo', 'intel_gpu_top', '-J', '-s', '1000'],
                                capture_output=True, text=True, timeout=5)

        output = result.stdout

        # Parse frequency (example: "freq": [300, 300, 0, 2050])
        freq_match = re.search(r'"freq":\s*\[(\d+),', output)
        if freq_match:
            gpu_freq.set(int(freq_match.group(1)))

        # Parse engine utilization (example: "Video/0": {"busy": 45.5})
        video_match = re.search(r'"Video/0":\s*{[^}]*"busy":\s*([\d.]+)', output)
        if video_match:
            gpu_video_busy.set(float(video_match.group(1)))

        render_match = re.search(r'"Render/3D/0":\s*{[^}]*"busy":\s*([\d.]+)', output)
        if render_match:
            gpu_render_busy.set(float(render_match.group(1)))

        compute_match = re.search(r'"Blitter/0":\s*{[^}]*"busy":\s*([\d.]+)', output)
        if compute_match:
            gpu_compute_busy.set(float(compute_match.group(1)))

        # Parse RC6 (example: "rc6": {"value": 98.5})
        rc6_match = re.search(r'"rc6":\s*{[^}]*"value":\s*([\d.]+)', output)
        if rc6_match:
            gpu_rc6.set(float(rc6_match.group(1)))

    except Exception as e:
        print(f"Error parsing intel_gpu_top: {e}")

if __name__ == '__main__':
    # Start Prometheus HTTP server on port 8080
    start_http_server(8080)
    print("Intel GPU exporter running on port 8080")

    # Collect metrics every 5 seconds
    while True:
        parse_intel_gpu_top()
        time.sleep(5)
PYTHON_EOF

sudo chmod +x intel_gpu_exporter.py

# Install Python dependencies
sudo apt install -y python3-pip python3-venv
sudo python3 -m venv venv
sudo venv/bin/pip install prometheus-client

# Create systemd service for GPU exporter
sudo tee /etc/systemd/system/intel-gpu-exporter.service > /dev/null <<'EOF'
[Unit]
Description=Intel GPU Prometheus Exporter
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/intel-gpu-exporter
ExecStart=/opt/intel-gpu-exporter/venv/bin/python3 /opt/intel-gpu-exporter/intel_gpu_exporter.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable intel-gpu-exporter
sudo systemctl start intel-gpu-exporter
echo "  ✓ Intel GPU exporter service running on port 8080"

# Verify services
echo ""
echo "======================================"
echo "Verification"
echo "======================================"
echo ""
echo "Plex Exporter Status:"
sudo systemctl status plex-exporter --no-pager | head -10
echo ""
echo "Intel GPU Exporter Status:"
sudo systemctl status intel-gpu-exporter --no-pager | head -10
echo ""
echo "Testing metrics endpoints..."
echo ""
echo "Plex metrics (port 9000):"
curl -s http://localhost:9000/metrics | grep -E "library_|server_info" | head -5
echo ""
echo "GPU metrics (port 8080):"
curl -s http://localhost:8080/metrics | grep "igpu_" | head -5
echo ""
echo "======================================"
echo "Installation Complete!"
echo "======================================"
echo ""
echo "Next steps:"
echo "1. Update Kubernetes service configs to use port 9000 (plex) and 8080 (GPU)"
echo "2. Apply configs: kubectl apply -k /Users/cbown75/git/kubernetes/clusters/korriban/apps/plex-monitoring/"
echo "3. Wait for Prometheus to scrape (2-3 minutes)"
echo "4. Check Grafana dashboard"
