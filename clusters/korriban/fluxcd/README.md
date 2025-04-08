# FluxCD Deployment Guide

## Overview

This directory contains Helm charts for deploying FluxCD v2 with GitOps support. The configuration includes:

- Multiple Git repository monitoring
- Notification support (Slack and Discord)
- Sealed Secrets integration
- Monitoring and resource management

## Installation

### Prerequisites

- Kubernetes cluster running v1.20+
- Helm v3.0+
- `kubectl` configured to access your cluster

### Pre-Installation Steps

Before installing, ensure any previous FluxCD installations or terminating CRDs are properly cleaned up:

```bash
# Check for any terminating CRDs
kubectl get crds | grep flux

# Force delete any terminating FluxCD CRDs if needed
kubectl patch crd <terminating-crd-name> -p '{"metadata":{"finalizers":[]}}' --type=merge
```

### Installing the Chart

```bash
# Navigate to the chart directory
cd clusters/korriban/fluxcd

# Install or upgrade
helm upgrade --install fluxcd . -n flux-system --create-namespace
```

### Configuration

The chart is configured through `values.yaml`. Key sections include:

- **Git Repositories**: Configure which repositories to monitor and paths within them
- **Controllers**: Enable/disable specific FluxCD controllers
- **Notifications**: Set up Slack or Discord alerts
- **Resources**: Configure CPU and memory limits

### Upgrading the Chart

When upgrading, ensure you handle API version changes correctly:

```bash
# Check for pending changes or notifications
kubectl get gitrepositories -A
kubectl get kustomizations -A

# Upgrade the helm chart
helm upgrade fluxcd . -n flux-system
```

## Troubleshooting

### Common Issues

1. **API Version Errors**: This chart has been updated to use stable v1 APIs. If you see warnings about deprecated APIs, ensure you're using the latest version of this chart.

2. **Port Name Issues**: Kubernetes limits port names to 15 characters. The chart has been updated to use shorter port names.

3. **CRD Termination Issues**: If you see errors about "CRD terminating", follow the pre-installation steps to clear any terminating CRDs.

4. **Secret Access Problems**: Ensure that the GitRepository objects have the correct secretRef configuration.

## Verification

Once deployed, verify the installation:

```bash
# Check FluxCD pods
kubectl get pods -n flux-system

# Check GitRepository status
kubectl get gitrepositories -n flux-system

# Check Kustomization status
kubectl get kustomizations -n flux-system
```

## Maintenance and Updates

When updating FluxCD versions, always check for API version changes and update the templates accordingly. Current controller images should be updated to their latest stable versions in the values file.
