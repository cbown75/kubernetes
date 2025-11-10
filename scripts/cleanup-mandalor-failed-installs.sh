#!/bin/bash

# Cleanup script for mandalor - removes ALL failed installation attempts
# Prepares for fresh installation of correct exporters

set -e

echo "======================================"
echo "Cleaning Up All Failed Installations"
echo "======================================"
echo ""
echo "This script will remove:"
echo "  - Old sfragata plex_exporter service and binary"
echo "  - /opt/prometheus-plex-exporter/ (failed attempts)"
echo "  - /opt/intel-gpu-exporter/ (failed attempts)"
echo "  - Any .zip files in /opt/"
echo ""

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "[1/5] Stopping and removing old sfragata plex-exporter service..."
sudo systemctl stop plex-exporter 2>/dev/null || true
sudo systemctl disable plex-exporter 2>/dev/null || true
sudo rm -f /etc/systemd/system/plex-exporter.service
sudo systemctl daemon-reload
echo "  ✓ Old plex-exporter service removed"

echo ""
echo "[2/5] Removing old plex_exporter binary..."
sudo rm -f /usr/local/bin/plex_exporter
echo "  ✓ Old binary removed"

echo ""
echo "[3/5] Removing failed prometheus-plex-exporter directory..."
if [ -d "/opt/prometheus-plex-exporter" ]; then
    sudo rm -rf /opt/prometheus-plex-exporter
    echo "  ✓ Removed /opt/prometheus-plex-exporter/"
else
    echo "  ℹ Directory does not exist, skipping"
fi

echo ""
echo "[4/5] Removing failed intel-gpu-exporter directory..."
if [ -d "/opt/intel-gpu-exporter" ]; then
    sudo rm -rf /opt/intel-gpu-exporter
    echo "  ✓ Removed /opt/intel-gpu-exporter/"
else
    echo "  ℹ Directory does not exist, skipping"
fi

echo ""
echo "[5/5] Removing any .zip files in /opt/..."
if ls /opt/*.zip 1> /dev/null 2>&1; then
    sudo rm -f /opt/*.zip
    echo "  ✓ Removed .zip files"
else
    echo "  ℹ No .zip files found, skipping"
fi

echo ""
echo "======================================"
echo "Cleanup Complete!"
echo "======================================"
echo ""
echo "Current plex-exporter status:"
sudo systemctl status plex-exporter --no-pager | head -10 || echo "Service not found (expected)"
echo ""
