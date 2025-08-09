# Provider configuration for AWS
# This configuration sets up the AWS provider for Terraform with a specific version and region.
# It requires Terraform version 1.5 or higher and uses AWS provider version 5.
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1" 
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "my-eks-cluster"
  cluster_version = "1.29"

  # Pull VPC info from aws-bootstrap remote state
  vpc_id     = data.terraform_remote_state.bootstrap.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.bootstrap.outputs.private_subnets

  enable_irsa = true

  eks_managed_node_groups = {
    default = {
      desired_size = 1
      max_size     = 2
      min_size     = 1

      instance_types = ["t3.medium"]
    }
  }
}

data "terraform_remote_state" "bootstrap" {
  backend = "s3"
  config = {
    bucket         = "my-tf-state-bucket"
    key            = "bootstrap/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
  }
}
