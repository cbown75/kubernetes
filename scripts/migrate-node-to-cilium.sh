#!/bin/bash
set -e

NODE_NAME=${1}
if [ -z "$NODE_NAME" ]; then
  echo "Usage: $0 <node-name>"
  echo "Available nodes:"
  kubectl get nodes --no-headers -o custom-columns=NAME:.metadata.name
  exit 1
fi

echo "=== Migrating node $NODE_NAME to Cilium ==="

# Step 1: Cordon node to prevent new scheduling
echo "Cordoning node $NODE_NAME..."
kubectl cordon $NODE_NAME

# Step 2: Gracefully drain node
echo "Draining node $NODE_NAME..."
kubectl drain $NODE_NAME \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --grace-period=30 \
  --timeout=300s \
  --force

# Step 3: Wait for pods to reschedule
echo "Waiting for pods to reschedule..."
sleep 30

# Step 4: Label node for Cilium takeover
echo "Labeling node for Cilium..."
kubectl label node $NODE_NAME --overwrite "io.cilium.migration/ready=true"

# Step 5: Restart Cilium agent on this node
echo "Restarting Cilium agent..."
kubectl -n cilium-system delete pod -l k8s-app=cilium \
  --field-selector spec.nodeName=$NODE_NAME

# Step 6: Wait for Cilium to be ready
echo "Waiting for Cilium to be ready..."
kubectl -n cilium-system wait --for=condition=Ready pod \
  -l k8s-app=cilium --field-selector spec.nodeName=$NODE_NAME \
  --timeout=300s

# Step 7: Test connectivity
echo "Testing connectivity..."
kubectl run test-$NODE_NAME --rm -i --tty \
  --overrides="{\"spec\":{\"nodeName\":\"$NODE_NAME\",\"tolerations\":[{\"operator\":\"Exists\"}]}}" \
  --image=busybox -- ping -c 3 8.8.8.8

# Step 8: Uncordon node
echo "Uncordoning node $NODE_NAME..."
kubectl uncordon $NODE_NAME

echo "✅ Node $NODE_NAME migration completed successfully"
