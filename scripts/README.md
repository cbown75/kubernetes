# Scripts Directory

This directory contains utility scripts for managing the Kubernetes infrastructure.

## Prometheus Secrets

### `create-prometheus-secrets.sh`

Creates sealed secrets for Prometheus deployment (placeholder for future secrets).

**Prerequisites:**

- `kubectl` installed and configured
- `kubeseal` installed ([installation guide](https://github.com/bitnami-labs/sealed-secrets#installation))
- Sealed Secrets controller running in cluster (`kube-system` namespace)
- Run from repository root directory
- `zsh` shell

**Usage:**

```bash
# Make script executable
chmod +x scripts/create-prometheus-secrets.sh

# Run the script
./scripts/create-prometheus-secrets.sh
```

**What it does:**

1. Validates prerequisites (kubectl, kubeseal, cluster connection)
2. Creates a placeholder sealed secret for future use
3. Creates sealed secret file at `clusters/korriban/apps/prometheus/sealed-secret.yaml`
4. Provides next steps for deployment

**Note:** Currently creates a placeholder secret. Prometheus is accessible without authentication at `https://prometheus.home.cwbtech.net`.

## AlertManager Secrets

### `create-alertmanager-secrets.sh`

Creates sealed secrets for AlertManager deployment with interactive prompts.

**Prerequisites:**

- `kubectl` installed and configured
- `kubeseal` installed ([installation guide](https://github.com/bitnami-labs/sealed-secrets#installation))
- Sealed Secrets controller running in cluster (`kube-system` namespace)
- Run from repository root directory
- `zsh` shell

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

## Grafana Secrets

### `create-grafana-secrets.sh`

Creates sealed secrets for Grafana deployment with both admin credentials and basic authentication.

**Prerequisites:**

- `kubectl` installed and configured
- `kubeseal` installed ([installation guide](https://github.com/bitnami-labs/sealed-secrets#installation))
- `htpasswd` installed (part of apache2-utils)
- Sealed Secrets controller running in cluster (`kube-system` namespace)
- Run from repository root directory
- `bash` shell

**Usage:**

```bash
# Make script executable
chmod +x scripts/create-grafana-secrets.sh

# Run the script
./scripts/create-grafana-secrets.sh
```

**What it does:**

1. Validates prerequisites (kubectl, kubeseal, htpasswd, cluster connection)
2. Prompts for Grafana admin password
3. Prompts for basic auth password
4. Creates sealed secret file at `clusters/korriban/apps/grafana/sealed-secret.yaml`
5. Provides next steps for deployment

**Secrets collected:**

| Secret               | Required | Description                                    |
| -------------------- | -------- | ---------------------------------------------- |
| `grafana admin`      | Yes      | Grafana admin user credentials                 |
| `grafana basic auth` | Yes      | Basic authentication for Grafana web interface |

## Example Workflows

### Prometheus Setup

```bash
# 1. Run the script
./scripts/create-prometheus-secrets.sh

# 2. Script will create placeholder secret
# 3. Review generated file
cat clusters/korriban/apps/prometheus/sealed-secret.yaml

# 4. Commit to git
git add clusters/korriban/apps/prometheus/sealed-secret.yaml
git commit -m "Add Prometheus sealed secrets"
git push

# 5. FluxCD will deploy automatically
# 6. Access Prometheus directly at https://prometheus.home.cwbtech.net
```

### AlertManager Setup

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

### Grafana Setup

```bash
# 1. Run the script
./scripts/create-grafana-secrets.sh

# 2. Script will prompt for admin and basic auth passwords
# 3. Review generated file
cat clusters/korriban/apps/grafana/sealed-secret.yaml

# 4. Commit to git
git add clusters/korriban/apps/grafana/sealed-secret.yaml
git commit -m "Add Grafana sealed secrets"
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

### Installing htpasswd (for Grafana only)

**macOS (Homebrew):**

```bash
brew install httpd
```

**Ubuntu/Debian:**

```bash
sudo apt-get install apache2-utils
```

**CentOS/RHEL:**

```bash
sudo yum install httpd-tools
```

### Verifying Sealed Secrets Controller

```bash
# Check if controller is running
kubectl get pods -n kube-system -l name=sealed-secrets-controller

# Check controller logs
kubectl logs -n kube-system -l name=sealed-secrets-controller
```

## Shell Compatibility

- **Prometheus script**: `zsh` compatible
- **AlertManager script**: `zsh` compatible
- **Grafana script**: `bash` compatible (uses bash-specific features)
