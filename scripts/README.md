# Scripts Directory

This directory contains utility scripts for managing the Kubernetes infrastructure.

## AlertManager Secrets

### `create-alertmanager-secrets.sh`

Creates sealed secrets for AlertManager deployment with interactive prompts.

**Prerequisites:**

- `kubectl` installed and configured
- `kubeseal` installed ([installation guide](https://github.com/bitnami-labs/sealed-secrets#installation))
- Sealed Secrets controller running in cluster (`kube-system` namespace)
- Run from repository root directory

**Usage:**

```bash
# Make script executable
chmod +x scripts/create-alertmanager-secrets.sh

# Run the script
./scripts/create-alertmanager-secrets.sh
```

**What it does:**

1. Validates prerequisites (kubectl, kubeseal, cluster connection)
2. Prompts for required secrets:
   - SMTP password (required)
   - Webhook password (can generate random)
   - PagerDuty key (optional)
   - Slack webhook URL (optional)
3. Creates sealed secret file at `clusters/korriban/apps/alertmanager/sealed-secret.yaml`
4. Provides next steps for deployment

**Secrets collected:**

| Secret              | Required | Description                                  |
| ------------------- | -------- | -------------------------------------------- |
| `slack-webhook-url` | Yes      | Slack webhook URL for notifications          |
| `smtp-password`     | No       | SMTP server password for email notifications |
| `webhook-password`  | No       | Authentication for custom webhook endpoints  |
| `pagerduty-key`     | No       | PagerDuty integration key                    |

**Example workflow:**

```bash
# 1. Run the script
./scripts/create-alertmanager-secrets.sh

# 2. Script will prompt for each secret
# 3. Review generated file
cat clusters/korriban/apps/alertmanager/sealed-secret.yaml

# 4. Commit to git
git add clusters/korriban/apps/alertmanager/sealed-secret.yaml
git commit -m "Add AlertManager sealed secrets"
git push

# 5. FluxCD will deploy automatically
```

## Installation Notes

### Installing kubeseal

**macOS (Homebrew):**

```bash
brew install kubeseal
```

**Linux:**

```bash
# Download latest release
KUBESEAL_VERSION=$(curl -s https://api.github.com/repos/bitnami-labs/sealed-secrets/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
wget "https://github.com/bitnami-labs/sealed-secrets/releases/download/${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"
tar -xvzf kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
```

**Windows:**

```powershell
# Using chocolatey
choco install kubeseal

# Or download from GitHub releases
```

### Verifying Sealed Secrets Controller

```bash
# Check if controller is running
kubectl get pods -n kube-system -l name=sealed-secrets-controller

# Check controller logs
kubectl logs -n kube-system -l name=sealed-secrets-controller
```
