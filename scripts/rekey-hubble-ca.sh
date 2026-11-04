#!/usr/bin/env bash
# Re-key the Cilium Hubble mTLS CA (infrastructure/cilium-hubble-pki), reissue
# both leaf certs from it, and restart the agents and hubble-relay.
# Runbook and prerequisites: clusters/korriban/infrastructure/README.md
#
# Usage (from the repository root):
#   ./scripts/rekey-hubble-ca.sh                # new CA key, new leaves, restart
#   ./scripts/rekey-hubble-ca.sh --leaves-only  # keep the CA: new leaf keys, restart.
#                                               # Use for a leaked leaf key, or to
#                                               # resume a run that failed after the
#                                               # CA step (re-running in full would
#                                               # re-key the CA again).
set -euo pipefail

NS=cilium-system
CA=cilium-hubble-ca
LEAVES=(hubble-server-tls hubble-relay-client-tls)
CA_WRITER=cert-manager-certificates-issuing

die() { echo "ERROR: $*" >&2; exit 1; }

# Public-key SHA-256 of the PEM cert in secret $1, data key $2. Fails if the
# Secret, the key or the PEM is missing or invalid.
fp() {
  local pem pub
  pem=$(kubectl -n "$NS" get secret "$1" -o "jsonpath={.data.${2//./\\.}}" | base64 -d) || return 1
  pub=$(printf '%s\n' "$pem" | openssl x509 -noout -pubkey 2>/dev/null) || return 1
  printf '%s\n' "$pub" | openssl sha256 | awk '{print $NF}'
}

pem_to() { kubectl -n "$NS" get secret "$1" -o 'jsonpath={.data.tls\.crt}' | base64 -d > "$2"; }

leaves_only=false
case "${1:-}" in
  "") ;;
  --leaves-only) leaves_only=true ;;
  *) die "usage: $0 [--leaves-only]" ;;
esac

# Preflight: nothing destructive runs until these pass.
for t in kubectl cmctl openssl base64 awk; do
  command -v "$t" >/dev/null || die "missing $t (cmctl: brew install cmctl)"
done
case "$(kubectl config current-context)" in
  admin@korriban | admin@talos-proxmox-cluster) ;;
  *) die "kube context is not the korriban cluster" ;;
esac
kubectl -n "$NS" get certificate "$CA" "${LEAVES[@]}" >/dev/null
kubectl -n "$NS" get ds cilium -o 'jsonpath={.spec.template.spec.volumes[*].projected.sources[*].secret.name}' \
  | tr ' ' '\n' | grep -qx "${LEAVES[0]}" \
  || die "cilium does not mount ${LEAVES[0]} yet (BOW-857); this PKI is not in use"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

if [ "$leaves_only" = false ]; then
  old=""
  if [ -n "$(kubectl -n "$NS" get secret "$CA" --ignore-not-found -o name)" ]; then
    old=$(fp "$CA" tls.crt) || die "cannot read the current CA"
  fi
  echo "Re-keying $CA"
  kubectl -n "$NS" delete secret "$CA" --ignore-not-found
  kubectl -n "$NS" wait --for=create "secret/$CA" --timeout=2m
  new=$(fp "$CA" tls.crt) || die "new $CA Secret has no valid certificate"
  [ "$new" != "$old" ] || die "CA key did not change"
  # rotationPolicy Never reuses whatever key is in the Secret, so a key planted
  # between the delete and the reissue would be adopted.
  writers=$(kubectl -n "$NS" get secret "$CA" \
    -o 'jsonpath={range .metadata.managedFields[*]}{.manager}{"\n"}{end}' | sort -u)
  [ "$writers" = "$CA_WRITER" ] || die "unexpected writers of $CA: $writers"
fi

new=$(fp "$CA" tls.crt) || die "cannot read $CA"
pem_to "$CA" "$tmp/ca.pem"
kubectl -n "$NS" wait "issuer/$CA" --for=condition=Ready --timeout=2m

before=()
for s in "${LEAVES[@]}"; do before+=("$(fp "$s" tls.crt 2>/dev/null || true)"); done

echo "Renewing ${LEAVES[*]}"
cmctl renew -n "$NS" "${LEAVES[@]}"

for i in "${!LEAVES[@]}"; do
  s=${LEAVES[$i]}
  ok=false
  for _ in $(seq 60); do
    if [ "$(fp "$s" tls.crt 2>/dev/null || true)" != "${before[$i]}" ] \
      && [ "$(fp "$s" ca.crt 2>/dev/null || true)" = "$new" ] \
      && pem_to "$s" "$tmp/leaf.pem" \
      && openssl verify -CAfile "$tmp/ca.pem" "$tmp/leaf.pem" >/dev/null 2>&1; then
      ok=true
      break
    fi
    sleep 2
  done
  [ "$ok" = true ] || die "$s was not reissued with a new key from $CA; fix the cause, then re-run with --leaves-only"
done

# Reloading the files only affects new handshakes. Restarting the agents ends
# streams opened with stolen certs; it cycles 2 nodes at a time and briefly
# interrupts each agent's L7/DNS proxy.
echo "Restarting ds/cilium and deploy/hubble-relay"
kubectl -n "$NS" rollout restart ds/cilium deploy/hubble-relay
kubectl -n "$NS" rollout status ds/cilium --timeout=15m
kubectl -n "$NS" rollout status deploy/hubble-relay --timeout=5m
echo "Done: $CA public key sha256 $new"
