terraform {
  required_version = ">= 1.5.0, < 2.0.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 4.67" }
  }
}

provider "aws" { region = "us-east-1" }

locals {
  name            = "gorilla-eks"
  cluster_version = "1.29"
}

# allow the deployer's IP to be injected at runtime
variable "endpoint_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"] # deploy.sh will override with ["<your-ip>/32"]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 4.0"

  name = "${local.name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a","us-east-1b","us-east-1c"]
  private_subnets = ["10.0.1.0/24","10.0.2.0/24","10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24","10.0.102.0/24","10.0.103.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.21"

  cluster_name    = local.name
  cluster_version = local.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_irsa = true

  # 🔓 Public endpoint for the deployer only (CIDR set by deploy.sh)
  cluster_endpoint_public_access       = true
  cluster_endpoint_private_access      = false
  cluster_endpoint_public_access_cidrs = var.endpoint_cidrs

  eks_managed_node_groups = {
    default = {
      desired_size   = 1
      min_size       = 1
      max_size       = 2
      instance_types = ["t3.medium"]
      disk_size      = 50
    }
  }
}
