# Netflix Clone Deployment on EKS with ArgoCD

This project deploys a Netflix clone application to Amazon EKS using Terraform for infrastructure and ArgoCD for GitOps deployment.

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- kubectl
- Git

## Quick Start

1. **Clone and setup:**
   ```bash
   git clone <your-repo-url>
   cd netflix-argocd-project
   chmod +x scripts/*.sh
   ```

2. **Deploy everything:**
   ```bash
   ./scripts/deploy.sh
   ```

3. **Access the application:**
   - Get LoadBalancer URL: `kubectl get svc netflix-service -n netflix`
   - Access ArgoCD UI: https://localhost:8080

4. **Cleanup:**
   ```bash
   ./scripts/cleanup.sh
   ```

## Architecture

- **EKS Cluster**: Managed Kubernetes cluster on AWS
- **VPC**: Custom VPC with public/private subnets
- **LoadBalancer**: AWS ALB for external access
- **ArgoCD**: GitOps continuous deployment
- **Netflix App**: Container from `johntoby/netflix:2`

## File Structure

```
├── terraform/          # EKS infrastructure
├── k8s-manifests/      # Kubernetes resources
├── argocd/             # ArgoCD configuration
└── scripts/            # Deployment scripts
```

## Manual Steps

If you prefer manual deployment:

1. **Deploy infrastructure:**
   ```bash
   cd terraform
   terraform init
   terraform apply
   ```

2. **Configure kubectl:**
   ```bash
   aws eks update-kubeconfig --region us-west-2 --name netflix-eks-cluster
   ```

3. **Install ArgoCD:**
   ```bash
   kubectl create namespace argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   ```

4. **Deploy application:**
   ```bash
   kubectl apply -f argocd/application.yaml
   ```


   ## Built by Johntoby.