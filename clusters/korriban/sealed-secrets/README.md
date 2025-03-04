# Sealed Secrets Helm Chart

This Helm chart deploys the Bitnami Sealed Secrets controller to your Kubernetes cluster, enabling secure management of Kubernetes secrets.

## Overview

[Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) provides a mechanism to encrypt your Kubernetes Secrets into SealedSecrets, which can be safely stored in a Git repository and included in your GitOps workflows.

## Prerequisites

- Kubernetes 1.16+
- Helm 3.0+

## Getting Started

To install the chart with the release name `sealed-secrets`:

```bash
helm install sealed-secrets ./sealed-secrets
```

## Configuration

The following table lists the configurable parameters of the Sealed Secrets chart and their default values.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `namespace` | Namespace for Sealed Secrets controller | `kube-system` |
| `controllerVersion` | Version of Sealed Secrets controller | `v0.22.0` |
| `resources` | Resource requests/limits for the controller | `{}` |
| `nodeSelector` | Node selectors for controller pod scheduling | `{}` |
| `tolerations` | Tolerations for controller pod scheduling | `[]` |
| `affinity` | Affinity rules for controller pod scheduling | `{}` |
| `extraArgs` | Additional controller arguments | `[]` |
| `service.type` | Service type for the controller | `ClusterIP` |
| `service.port` | Service port for the controller | `8080` |
| `customSecrets` | List of custom SealedSecrets to deploy | `[]` |

## Working with Sealed Secrets

### Creating Sealed Secrets

To create a sealed secret:

1. Install the kubeseal CLI tool:
   ```bash
   brew install kubeseal  # On macOS
   ```

2. Create a regular Secret manifest:
   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: mysecret
     namespace: default
   type: Opaque
   stringData:
     username: admin
     password: supersecret
   ```

3. Encrypt it using kubeseal:
   ```bash
   kubeseal --format yaml < secret.yaml > sealed-secret.yaml
   ```

4. You can either apply the generated sealed-secret.yaml directly:
   ```bash
   kubectl apply -f sealed-secret.yaml
   ```

   Or add it to the `customSecrets` section in your values.yaml file:
   ```yaml
   customSecrets:
     - name: mysecret
       namespace: default
       encryptedData:
         username: "AgBy8hCF8..."  # Copy encrypted data from sealed-secret.yaml
         password: "AgAT671..."    # Copy encrypted data from sealed-secret.yaml
   ```

## Integration with FluxCD

This chart works well with the companion FluxCD chart. To use them together:

1. Install Sealed Secrets first:
   ```bash
   helm install sealed-secrets ./sealed-secrets
   ```

2. Install FluxCD with Git repository secrets:
   ```bash
   helm install flux ./flux-system
   ```

The FluxCD GitRepository resources can reference secrets that are created by the Sealed Secrets controller.