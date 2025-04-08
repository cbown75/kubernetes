# FluxCD Helm Chart

## Overview

This is a Helm chart for installing [FluxCD](https://fluxcd.io/) with support for multiple Git repositories and notifications.

## Chart Details

- **Name**: `fluxcd`
- **Version**: 0.1.0
- **App Version**: 1.0
- **Type**: Application
- **Description**: Deploy FluxCD with notifications and multiple Git repositories.

## Installation

### Prerequisites

- Helm 3+
- Kubernetes Cluster
- FluxCD CLI (optional, but recommended)

### Installing the Chart

```sh
helm repo add my-repo https://my.repo.url
helm install my-fluxcd my-repo/fluxcd -f values.yaml
```

### Upgrading the Chart

```sh
helm upgrade my-fluxcd my-repo/fluxcd -f values.yaml
```

### Uninstalling the Chart

```sh
helm uninstall my-fluxcd
```

## Configuration

This chart can be configured through `values.yaml`. Below are some key configurations:

### Notifications

Supports Slack and Discord:

```yaml
notifications:
  slack:
    enabled: false
    webhookUrl: ""
  discord:
    enabled: false
    webhookUrl: ""
```

### Git Repositories

Multiple repositories can be configured:

```yaml
gitRepositories:
  - name: "example-repo"
    url: "https://github.com/your-org/example-repo.git"
    interval: "1m"
    paths:
      - "clusters/apps"
```

### FluxCD Controllers

Define FluxCD components to install:

```yaml
controllers:
  installFluxControllers: true
  helmController:
    enabled: true
  notificationController:
    enabled: true
```

### RBAC

```yaml
rbac:
  enabled: true
  serviceAccountName: "flux-sa"
```

### ServiceMonitor

For enabling Prometheus monitoring:

```yaml
serviceMonitor:
  enabled: false
  interval: 30s
```

### Resources

Set resource requests and limits:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi
```

## License

This project is licensed under the MIT License.
