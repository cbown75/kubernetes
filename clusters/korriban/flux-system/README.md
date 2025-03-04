# FluxCD Helm Chart

This Helm chart deploys FluxCD resources to a Kubernetes cluster.

## Prerequisites

- Kubernetes 1.16+
- Helm 3.0+

## Getting Started

To install the chart with the release name `my-flux`:

```bash
helm install my-flux ./flux-system
```

## Configuration

The following table lists the configurable parameters of the FluxCD chart and their default values.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `namespace` | Namespace where FluxCD components will be installed | `flux-system` |
| `repositories` | List of GitRepository configurations | `[]` |
| `repositories[].name` | Name of the GitRepository | `nil` |
| `repositories[].url` | URL of the Git repository | `nil` |
| `repositories[].branch` | Branch to sync | `main` |
| `repositories[].path` | Path within the repository | `./` |
| `repositories[].interval` | Sync interval | `1m` |
| `repositories[].secretName` | Name of the Secret containing Git credentials | `nil` |
| `controllers.source.enabled` | Enable source controller | `true` |
| `controllers.kustomize.enabled` | Enable kustomize controller | `true` |
| `controllers.helm.enabled` | Enable helm controller | `true` |
| `controllers.notification.enabled` | Enable notification controller | `true` |
| `defaultInterval` | Default interval for reconciliation | `1m` |

## Example values.yaml

```yaml
namespace: flux-system

repositories:
  - name: app1
    url: https://github.com/organization/app1
    branch: main
    path: ./deploy
    interval: 1m
    secretName: github-token-app1
  - name: app2
    url: https://github.com/organization/app2
    branch: develop
    path: ./k8s
    interval: 5m
    secretName: github-token-app2

controllers:
  source:
    enabled: true
  kustomize:
    enabled: true
  helm:
    enabled: true
  notification:
    enabled: true

defaultInterval: 1m
```

## Integration with Sealed Secrets

For secure management of Git credentials, this chart works well with the companion [Sealed Secrets](../sealed-secrets/README.md) chart.

To use them together:

1. Install Sealed Secrets first:
   ```bash
   helm install sealed-secrets ./sealed-secrets
   ```

2. Create sealed secrets for your Git repository credentials:
   ```bash
   # Create a regular secret
   cat <<EOF > github-token-app1.yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: github-token-app1
     namespace: flux-system
   type: Opaque
   stringData:
     username: your-username
     password: your-personal-access-token
   EOF

   # Seal it
   kubeseal --format yaml < github-token-app1.yaml > sealed-github-token-app1.yaml
   
   # Apply the sealed secret
   kubectl apply -f sealed-github-token-app1.yaml
   ```

3. Reference these secrets in your FluxCD values.yaml:
   ```yaml
   repositories:
     - name: app1
       url: https://github.com/organization/app1
       branch: main
       path: ./deploy
       interval: 1m
       secretName: github-token-app1
   ```

4. Install FluxCD:
   ```bash
   helm install flux ./flux-system
   ```

For more information on working with Sealed Secrets, refer to the [Sealed Secrets README](../sealed-secrets/README.md).