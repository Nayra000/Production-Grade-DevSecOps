

resource "aws_secretsmanager_secret" "mongodb" {
  name                    = "mongodb-credentials"
  description             = "MongoDB credentials"
  recovery_window_in_days = 7

}



resource "aws_iam_policy" "myapp_secrets" {
  name   = "myapp-secrets-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.mongodb.arn
      }
    ]
  })
}

resource "aws_iam_role" "myapp_secrets_role" {
  name = "myapp-secrets-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.eks_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(var.eks_url, "https://", "")}:sub" = "system:serviceaccount:myapp:secretmanager-sa"
          "${replace(var.eks_url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.myapp_secrets_role.name
  policy_arn = aws_iam_policy.myapp_secrets.arn
}