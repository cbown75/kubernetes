# Scripts Directory

This directory contains utility scripts for managing Kubernetes sealed secrets using the overlay structure.

## Overview

All scripts generate sealed secrets following the **base/overlay pattern**:

- Base configs in `apps/<app-name>/base/`
- Cluster-specific secrets in `apps/<app-name>/overlay/korriban/sealed-secrets.yaml`

## Available Scripts

### 1. Grafana Secrets

**Script:** `create-grafana-secrets.sh`

Creates sealed secrets for Grafana with both admin credentials and basic authentication.

**Prerequisites:**

- `kubectl` installed and configured
- `kubeseal` installed
- `htpasswd` installed (apache2-utils)
- Sealed Secrets controller running in cluster
- `bash` shell

**Output:** `apps/grafana/overlay/korriban/sealed-secrets.yaml`

**Usage:**

```bash
./scripts/create-grafana-secrets.sh
```

**Secrets collected:**

- Admin username and password
- Basic auth credentials for Istio gateway

---

### 2. AlertManager Secrets

**Script:** `create-alertmanager-secrets.sh`

Creates sealed secrets for AlertManager with notification endpoints.

**Prerequisites:**

- `kubectl` installed and configured
- `kubeseal` installed
- Sealed Secrets controller running in cluster
- `zsh` shell

**Output:** `apps/alertmanager/overlay/korriban/sealed-secrets.yaml`

**Usage:**

```bash
./scripts/create-alertmanager-secrets.sh
```

**Secrets collected:**

- Slack webhook URL (required)
- SMTP password (optional)
- Webhook password (optional, auto-generated)
- PagerDuty key (optional)

---

### 3. Prometheus Secrets

**Script:** `create-prometheus-secrets.sh`

Creates placeholder sealed secrets for Prometheus (currently no auth).

**Prerequisites:**

- `kubectl` installed and configured
- `kubeseal` installed
- Sealed Secrets controller running in cluster
- `zsh` shell

**Output:** `apps/prometheus/overlay/korriban/sealed-secrets.yaml`

**Usage:**

```bash
./scripts/create-prometheus-secrets.sh
```

**Note:** Currently creates placeholder secret. Prometheus is accessible without authentication.

---

### 4. Cloudflared Secrets

**Script:** `create-cloudflared-secrets.sh`

Creates sealed secrets for Cloudflare Tunnel with credentials.

**Prerequisites:**

- `kubectl` installed and configured
- `kubeseal` installed
- Sealed Secrets controller running in cluster
- `bash` shell

**Output:** `apps/cloudflared/overlay/korriban/sealed-secrets.yaml`

**Usage:**

```bash
./scripts/create-cloudflared-secrets.sh
```

**Secrets collected:**

- Cloudflare Account ID
- Tunnel ID
- Tunnel Name
- Tunnel Secret

---

### 5. N8N Secrets

**Script:** `generate-n8n-sealed-secrets.sh`

Creates sealed secrets for N8N automation platform.

**Prerequisites:**

- `kubectl` installed and configured
- `kubeseal` installed
- `openssl` installed
- Sealed Secrets controller running in cluster
- `bash` shell

**Output:** `apps/n8n/overlay/korriban/sealed-secrets.yaml`

**Usage:**

```bash
./scripts/generate-n8n-sealed-secrets.sh
```

**Secrets collected:**

- PostgreSQL user and password
- Redis password
- Encryption key (auto-generated if not provided)

---

## General Workflow

All scripts follow this pattern:

### 1. Run Script

```bash
./scripts/create-<app>-secrets.sh
```

### 2. Enter Credentials

Script will prompt for required secrets (passwords, API keys, etc.)

### 3. Review Output

```bash
cat apps/<app>/overlay/korriban/sealed-secrets.yaml
```

### 4. Commit to Git

```bash
git add apps/<app>/overlay/korriban/sealed-secrets.yaml
git commit -m "Add <app> sealed secrets"
git push
```

### 5. FluxCD Deploys Automatically

FluxCD watches the git repository and deploys changes automatically.

---

## Prerequisites Installation

### kubeseal

**macOS (Homebrew):**

```bash
brew install kubeseal
```

**Linux:**

```bash
KUBESEAL_VERSION=$(curl -s https://api.github.com/repos/bitnami-labs/sealed-secrets/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
wget "https://github.com/bitnami-labs/sealed-secrets/releases/download/${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"
tar -xvzf kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
```

**Windows (Chocolatey):**

```powershell
choco install kubeseal
```

### htpasswd (Grafana only)

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

### Verify Sealed Secrets Controller

```bash
# Check if controller is running
kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets

# Check controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=sealed-secrets
```

---

## Directory Structure

```
scripts/
├── README.md                              # This file
├── create-grafana-secrets.sh              # Grafana secrets
├── create-alertmanager-secrets.sh         # AlertManager secrets
├── create-prometheus-secrets.sh           # Prometheus secrets
├── create-cloudflared-secrets.sh          # Cloudflared secrets
└── generate-n8n-sealed-secrets.sh         # N8N secrets

apps/
├── grafana/
│   └── overlay/
│       └── korriban/
│           └── sealed-secrets.yaml        # Grafana secrets
├── alertmanager/
│   └── overlay/
│       └── korriban/
│           └── sealed-secrets.yaml        # AlertManager secrets
├── prometheus/
│   └── overlay/
│       └── korriban/
│           └── sealed-secrets.yaml        # Prometheus secrets (placeholder)
├── cloudflared/
│   └── overlay/
│       └── korriban/
│           └── sealed-secrets.yaml        # Cloudflared secrets
└── n8n/
    └── overlay/
        └── korriban/
            └── sealed-secrets.yaml        # N8N secrets
```

---

## Troubleshooting

### Script Can't Find Directory

**Error:** `Please run this script from the repository root`

**Solution:**

```bash
cd /path/to/kubernetes-repo
./scripts/create-<app>-secrets.sh
```

### Kubeseal Not Found

**Error:** `kubeseal is not installed`

**Solution:** Install kubeseal (see Prerequisites Installation above)

### Can't Connect to Cluster

**Error:** `Cannot connect to Kubernetes cluster`

**Solution:**

```bash
# Verify kubectl is configured
kubectl cluster-info

# Check current context
kubectl config current-context

# If needed, switch context
kubectl config use-context <context-name>
```

### Sealed Secrets Controller Not Running

**Error:** `Sealed Secrets controller is not running`

**Solution:**

```bash
# Check controller status
kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets

# If not running, redeploy sealed-secrets
# (refer to sealed-secrets installation docs)
```

---

## Security Notes

1. **Never commit unencrypted secrets** - Only commit sealed-secrets.yaml files
2. **Keep encryption keys safe** - Store in password manager (especially N8N encryption key)
3. **Backup sealed-secrets private key** - Backup the controller's private key for disaster recovery:
   ```bash
   kubectl get secret -n kube-system sealed-secrets-key -o yaml > sealed-secrets-key-backup.yaml
   ```
4. **Limit script access** - Mark scripts as executable only for authorized users
5. **Use strong passwords** - Generate random passwords for better security

---

## Shell Compatibility

- **Grafana:** `bash` (uses bash-specific features)
- **AlertManager:** `zsh` (zsh compatible)
- **Prometheus:** `zsh` (zsh compatible)
- **Cloudflared:** `bash` (bash compatible)
- **N8N:** `bash` (bash compatible)

---

## Contributing

When creating new secret generation scripts:

1. Follow the existing pattern (check prerequisites, prompt for secrets, create sealed secret)
2. Output to `apps/<app-name>/overlay/korriban/sealed-secrets.yaml`
3. Use proper labels in sealed secrets
4. Add comprehensive error handling
5. Document in this README
6. Test thoroughly before committing
