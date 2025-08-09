resource "aws_iam_role" "eks_deployment" {
  name = "EKSDeploymentRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = "arn:aws:iam::<YOUR_ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:gsaffouri/eks-deployment:ref:refs/heads/main"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "eks_policy" {
  name = "EKSDeploymentPolicy"
  role = aws_iam_role.eks_deployment.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "eks:*",
          "ec2:Describe*",
          "iam:PassRole",
          "autoscaling:*",
          "elasticloadbalancing:*"
        ],
        Resource = "*"
      }
    ]
  })
}

output "eks_deployment_role_arn" {
  value = aws_iam_role.eks_deployment.arn
}
