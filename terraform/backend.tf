terraform {
  backend "s3" {
    bucket         = "my-terraform-state-105489233077"
    key            = "eks/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile = true
  }
}