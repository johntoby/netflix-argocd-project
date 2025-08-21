#!/bin/bash

set -e

echo "🚀 Starting Netflix Clone Deployment to EKS with ArgoCD"

# Step 1: Deploy EKS Infrastructure
echo "📦 Deploying EKS infrastructure with Terraform..."
cd terraform
terraform init
terraform apply -auto-approve

# Get cluster info from terraform outputs
CLUSTER_NAME=$(terraform output -raw cluster_name)
REGION=$(terraform output -raw region)

echo "✅ EKS cluster and AWS Load Balancer Controller deployed: $CLUSTER_NAME in region $REGION"

# Step 2: Configure kubectl
echo "🔧 Configuring kubectl..."
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

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

echo "ArgoCD UI available at: https://localhost:8080"
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"

# Step 6: Deploy Netflix application via ArgoCD
echo "🎬 Deploying Netflix application..."
cd ../argocd
kubectl apply -f application.yaml

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
echo "🌐 To get LoadBalancer URL:"
echo "kubectl get svc netflix-service -n netflix -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"

# Keep port forward running
echo "Press Ctrl+C to stop port forwarding and exit"
wait $PORTFORWARD_PID