#!/bin/bash

set -euo pipefail

# Resolve paths relative to the repo root so the script works from any directory
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🚀 Starting Netflix Clone Deployment to EKS with ArgoCD"

# Step 1: Deploy EKS Infrastructure
echo "📦 Deploying EKS infrastructure with Terraform..."
cd "$REPO_ROOT/terraform"

# Add Helm repository
echo "📚 Adding Helm repositories..."
helm repo add eks https://aws.github.io/eks-charts
helm repo update

terraform init
terraform apply -auto-approve

# Get cluster info from terraform outputs
CLUSTER_NAME=$(terraform output -raw cluster_name)
REGION=$(terraform output -raw region)

echo "✅ EKS cluster deployed: $CLUSTER_NAME in region $REGION"

# Step 2: Configure kubectl
echo "🔧 Configuring kubectl..."
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"

# Step 2.5: Install AWS Load Balancer Controller
echo "🔧 Installing AWS Load Balancer Controller..."
LB_ROLE_ARN=$(terraform output -raw aws_lb_controller_role_arn)

# Install or upgrade in one idempotent step (safe to re-run)
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="$CLUSTER_NAME" \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="$LB_ROLE_ARN"

# Wait for AWS Load Balancer Controller to be ready
echo "⏳ Waiting for AWS Load Balancer Controller to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/aws-load-balancer-controller -n kube-system

# Step 3: Install ArgoCD
echo "🔄 Installing ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
echo "⏳ Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Step 4: Get ArgoCD admin password
echo "🔑 Getting ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD Admin Password: $ARGOCD_PASSWORD"

# Step 5: Port forward ArgoCD (optional - for local access)
echo "🌐 Setting up ArgoCD port forward..."
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
PORTFORWARD_PID=$!
trap 'kill "$PORTFORWARD_PID" 2>/dev/null || true' EXIT

echo "ArgoCD UI available at: https://localhost:8080"
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"

# Step 6: Deploy Netflix application via ArgoCD
echo "🎬 Deploying Netflix application..."
kubectl apply -f "$REPO_ROOT/argocd/application.yaml"

echo "✅ Deployment completed!"
echo ""
echo "📋 Summary:"
echo "- EKS Cluster: $CLUSTER_NAME"
echo "- Region: $REGION"
echo "- ArgoCD UI: https://localhost:8080"
echo "- ArgoCD Username: admin"
echo "- ArgoCD Password: $ARGOCD_PASSWORD"
echo ""
echo "🔍 To check Netflix service status:"
echo "kubectl get svc netflix-service -n netflix"
echo ""
echo "🌐 netflix-service is ClusterIP (not internet-facing). To open the app locally:"
echo "kubectl port-forward svc/netflix-service -n netflix 8081:80   # then http://localhost:8081"

# Keep port forward running
echo "Press Ctrl+C to stop port forwarding and exit"
wait "$PORTFORWARD_PID"