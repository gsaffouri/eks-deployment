# Remote State - Get Bootstrap Outputs Automatically
data "terraform_remote_state" "bootstrap" {
  backend = "s3"
  config = {
    bucket = "my-tf-state-bucket-08040627"
    key    = "aws-bootstrap/terraform.tfstate"
    region = "us-east-1"
  }
}



# EKS Cluster Module
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "gorilla-eks-cluster"
  cluster_version = "1.29"

  cluster_endpoint_public_access = true

  # Automatically pull values from tf-bootstrap
  vpc_id     = data.terraform_remote_state.bootstrap.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.bootstrap.outputs.public_subnets

  eks_managed_node_groups = {
    gorilla_node_group = {
      min_size     = 1
      max_size     = 3
      desired_size = 1

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"

      labels = {
        Environment = "Dev"
        ManagedBy   = "Terraform"
      }
    }
  }

  # Enable IAM OIDC provider for IRSA
  enable_irsa = true

  tags = {
    Environment = "Dev"
    Project     = "EKS"
    Owner       = "gorilla"
  }
}
