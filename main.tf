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

