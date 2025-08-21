#!/bin/bash

set -e

echo "🧹 Cleaning up Netflix deployment..."

# Remove ArgoCD application
echo "🗑️ Removing ArgoCD application..."
kubectl delete -f ../argocd/application.yaml --ignore-not-found=true

# Remove Netflix resources
echo "🗑️ Removing Netflix resources..."
kubectl delete namespace netflix --ignore-not-found=true

# Remove ArgoCD
echo "🗑️ Removing ArgoCD..."
kubectl delete namespace argocd --ignore-not-found=true

# Destroy Terraform infrastructure
echo "💥 Destroying EKS infrastructure..."
cd ../terraform
terraform destroy -auto-approve

echo "✅ Cleanup completed!"