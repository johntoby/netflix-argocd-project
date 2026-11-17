#!/bin/bash

set -euo pipefail

# Resolve paths relative to the repo root so the script works from any directory
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🧹 Cleaning up Netflix deployment..."

# Remove ArgoCD application
echo "🗑️ Removing ArgoCD application..."
kubectl delete -f "$REPO_ROOT/argocd/application.yaml" --ignore-not-found=true

# Remove Netflix resources
echo "🗑️ Removing Netflix resources..."
kubectl delete namespace netflix --ignore-not-found=true

# Remove ArgoCD
echo "🗑️ Removing ArgoCD..."
kubectl delete namespace argocd --ignore-not-found=true

# Destroy Terraform infrastructure
echo "💥 Destroying EKS infrastructure..."
cd "$REPO_ROOT/terraform"
terraform destroy -auto-approve

echo "✅ Cleanup completed!"