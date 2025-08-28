# Agent Guidelines for Kubernetes GitOps Repository

## Commands
- **Lint**: No specific linting (commitlint runs in CI)
- **Test**: `kubectl apply --dry-run=client -f <file>` (validate YAML)
- **Deploy**: Changes auto-deploy via FluxCD within 1 minute

## Repository Structure
- **Kubernetes manifests only** - no application code
- **GitOps with FluxCD** - all changes deploy automatically
- **HelmReleases, Kustomizations, and vanilla manifests**
- **Sealed secrets for sensitive data**

## Style Guidelines
- **YAML formatting**: 2-space indentation, no tabs
- **Resource naming**: kebab-case (e.g., `grafana-admin-secret`)
- **Labels**: Always include `app.kubernetes.io/name`, `app.kubernetes.io/part-of`
- **Namespaces**: Explicit namespace in metadata for all namespaced resources
- **Comments**: Brief inline comments for complex configurations only
- **File organization**: One resource type per file when possible

## Security & Best Practices
- **Never commit plain secrets** - use SealedSecrets only
- **Include security contexts** with runAsNonRoot, readOnlyRootFilesystem
- **Pod security labels** on namespaces (enforce: privileged/restricted)
- **Resource limits** always specified for production workloads
- **NetworkPolicies** for traffic isolation between namespaces

## Critical Notes
- **FluxCD manages everything** - manual kubectl changes get reverted
- **Test changes with dry-run first** before committing
- **Check FluxCD status**: `flux get all` and `kubectl get kustomizations -A`