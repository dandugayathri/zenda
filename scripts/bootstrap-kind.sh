#!/usr/bin/env bash
set -euo pipefail

for cmd in docker kind kubectl; do
  command -v "$cmd" >/dev/null || { echo "Missing required command: $cmd" >&2; exit 1; }
done
docker info >/dev/null || { echo "Start Docker Desktop first." >&2; exit 1; }

cd "$(dirname "$0")/.."
if ! kind get clusters | grep -qx zenda; then
  kind create cluster --name zenda --config kind-config.yaml --wait 5m
fi
kubectl config use-context kind-zenda
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace zenda --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.6.1/manifests/install.yaml
kubectl -n argocd rollout status deployment/argocd-server --timeout=5m
kubectl get nodes
echo "After pushing both branches, apply argocd/application.yaml to start GitOps sync."
