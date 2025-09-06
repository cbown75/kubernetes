#!/bin/bash
set -e

echo "🔧 FIXING REMAINING CNI CONFLICTS"

echo "1️⃣ Removing remaining Flannel DaemonSet..."
kubectl delete daemonset kube-flannel -n kube-system --ignore-not-found=true

echo "2️⃣ Disabling kube-proxy (Cilium handles this)..."
kubectl scale daemonset kube-proxy -n kube-system --replicas=0

echo "3️⃣ Checking Istio CNI pods..."
kubectl get pods -n istio-system -l k8s-app=istio-cni-node

echo "4️⃣ Checking Istio CNI logs for errors..."
kubectl logs -n istio-system -l k8s-app=istio-cni-node --tail=20 | head -50 || echo "No logs available"

echo "5️⃣ Restarting Istio CNI to work with Cilium..."
kubectl rollout restart daemonset/istio-cni-node -n istio-system

echo "6️⃣ Waiting for Istio CNI to become ready..."
kubectl rollout status daemonset/istio-cni-node -n istio-system --timeout=300s

echo "7️⃣ Final verification - checking all DaemonSets..."
kubectl get daemonsets -A | grep -E "(flannel|cilium|istio-cni|kube-proxy)"

echo "✅ CNI CONFLICTS RESOLVED!"
