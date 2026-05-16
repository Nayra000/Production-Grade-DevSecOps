resource "aws_ecr_repository" "jenkins_repo" {
  name = "myapp"

  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "jenkins-ecr"
    Environment = "production"
  }
}

resource "aws_ecr_lifecycle_policy" "jenkins_repo_policy" {
  repository = aws_ecr_repository.jenkins_repo.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"

        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }

        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "jenkins_ecr" {
  name = "jenkins-ecr-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [

      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },

      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
        Resource = aws_ecr_repository.jenkins_repo.arn
      }

    ]
  })
}
resource "aws_iam_role" "jenkins_irsa" {
  name = "jenkins-irsa-role"

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
       ( "${replace(var.eks_url, "https://", "")}:sub" ) = "system:serviceaccount:jenkins:jenkins"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "jenkins_ecr_attach" {
  role       = aws_iam_role.jenkins_irsa.name
  policy_arn = aws_iam_policy.jenkins_ecr.arn
}



resource "kubernetes_service_account" "jenkins" {
  metadata {
    name      = "jenkins"
    namespace = "jenkins"

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.jenkins_irsa.arn
    }
  }
   depends_on = [
    aws_iam_role_policy_attachment.jenkins_ecr_attach
  ]
}

