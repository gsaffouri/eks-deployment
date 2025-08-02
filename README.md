<p align="center">
  <a href="https://github.com/gsaffouri/eks-deploy/actions">
    <img src="https://github.com/gsaffouri/eks-deploy/actions/workflows/lint.yml/badge.svg?branch=main&label=CI%2FCD&logo=githubactions&style=flat-square" alt="CI/CD">
  </a>
  <img src="https://img.shields.io/badge/Terraform-1.5%2B-blueviolet?logo=terraform&style=flat-square" alt="Terraform Version">
  <img src="https://img.shields.io/badge/EKS%20Cluster-Managed-blue?logo=kubernetes&style=flat-square" alt="EKS Cluster">
  <img src="https://img.shields.io/badge/AWS%20Certified-%F0%9F%94%A5-orange?style=flat-square" alt="AWS Certified">
  <img src="https://img.shields.io/badge/Certified%20CKA-%F0%9F%8F%86-blue?style=flat-square" alt="CKA Certified">
  <img src="https://img.shields.io/github/license/gsaffouri/eks-deploy?style=flat-square" alt="license">
  <img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square" alt="PRs Welcome">
</p>

---

# 🎯 EKS Deploy

This repo uses Terraform to deploy a production-ready **Amazon EKS cluster** with a managed node group, leveraging the official [`terraform-aws-modules/eks/aws`](https://github.com/terraform-aws-modules/terraform-aws-eks) module.

It pulls core networking resources (VPC, subnets, remote state config) from the [aws-bootstrap](https://github.com/gsaffouri/aws-bootstrap) repo via S3 backend and `terraform_remote_state`.

---

## 🧱 Infrastructure Overview

- 🚀 **Amazon EKS**: 1.29+
- 🧠 **Managed Node Group**: 1 node to start (autoscaling ready)
- 🌍 **Private Subnets**: pulled from remote state
- 🔒 **IAM OIDC Integration**: ready for GitHub Actions & IRSA
- 📦 **Terraform Remote State**: backed by S3 + DynamoDB

---

## 📂 Folder Structure

