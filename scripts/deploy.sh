#!/bin/bash

set -e

echo "🚀 Starting Netflix Clone Deployment to EKS with ArgoCD"

# Step 1: Deploy EKS Infrastructure
echo "📦 Deploying EKS infrastructure with Terraform..."
cd terraform

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
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

# Step 2.5: Install AWS Load Balancer Controller
echo "🔧 Installing AWS Load Balancer Controller..."
LB_ROLE_ARN=$(terraform output -raw aws_lb_controller_role_arn)

# Check if already installed, if so upgrade, otherwise install
if helm list -n kube-system | grep -q aws-load-balancer-controller; then
  echo "AWS Load Balancer Controller already exists, upgrading..."
  helm upgrade aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=$CLUSTER_NAME \
    --set serviceAccount.create=true \
    --set serviceAccount.name=aws-load-balancer-controller \
    --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$LB_ROLE_ARN
else
  echo "Installing AWS Load Balancer Controller..."
  helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=$CLUSTER_NAME \
    --set serviceAccount.create=true \
    --set serviceAccount.name=aws-load-balancer-controller \
    --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$LB_ROLE_ARN
fi

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