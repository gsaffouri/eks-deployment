terraform {
  required_version = "~> 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Pull outputs from aws-bootstrap remote state
data "terraform_remote_state" "bootstrap" {
  backend = "s3"
  config = {
    bucket         = "my-tf-state-bucket-08040627"  # From aws-bootstrap
    key            = "bootstrap/terraform.tfstate" # Path used in bootstrap
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
  }
}

# Deploy EKS cluster using existing VPC
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "my-eks-cluster"
  cluster_version = "1.29"

  # From aws-bootstrap outputs
  vpc_id     = data.terraform_remote_state.bootstrap.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.bootstrap.outputs.private_subnets

  enable_irsa = true

  eks_managed_node_groups = {
    default = {
      desired_size   = 1
      max_size       = 2
      min_size       = 1
      instance_types = ["t3.medium"]
    }
  }
}
