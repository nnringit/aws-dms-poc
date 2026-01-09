# -----------------------------------------------------------------------------
# IAM Policy for DMS POC - Grants necessary permissions for the POC
# -----------------------------------------------------------------------------

# Get current user info
data "aws_iam_user" "current" {
  user_name = split("/", data.aws_caller_identity.current.arn)[1]
}

# IAM Policy for RDS and DMS access
resource "aws_iam_policy" "dms_poc_policy" {
  name        = "${var.project_name}-full-access-policy"
  description = "Policy granting RDS and DMS access for DMS POC"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RDSFullAccess"
        Effect = "Allow"
        Action = [
          "rds:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "DMSFullAccess"
        Effect = "Allow"
        Action = [
          "dms:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "EC2ForDMS"
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcs",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:ModifyNetworkInterfaceAttribute",
          "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeNetworkInterfaces"
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMPassRole"
        Effect = "Allow"
        Action = [
          "iam:PassRole",
          "iam:GetRole"
        ]
        Resource = "*"
      },
      {
        Sid    = "KMSForRDS"
        Effect = "Allow"
        Action = [
          "kms:CreateGrant",
          "kms:DescribeKey",
          "kms:ListAliases"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-full-access-policy"
  }
}

# Attach policy to current user
resource "aws_iam_user_policy_attachment" "dms_poc_attachment" {
  user       = data.aws_iam_user.current.user_name
  policy_arn = aws_iam_policy.dms_poc_policy.arn
}
