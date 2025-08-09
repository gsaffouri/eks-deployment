#!/usr/bin/env bash
set -euo pipefail

ACTION=${1:-}

if [[ "$ACTION" != "-p" ]]; then
  echo "Usage: $0 -p"
  echo "  -p    Provision EKS cluster"
  exit 1
fi

echo "Deploying EKS cluster from eks-deployment..."

# 1. Initialize Terraform
echo "Initializing Terraform..."
terraform init -input=false

# 2. Format check
echo "Checking Terraform formatting..."
terraform fmt -check -recursive

# 3. Validate syntax
echo "Validating Terraform configuration..."
terraform validate

# 4. Plan
echo "Planning deployment..."
terraform plan -out=tfplan -input=false

# 5. Apply
echo "Applying changes..."
terraform apply -input=false tfplan

echo "EKS cluster deployed successfully!"
