data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

module "vpc" {
  source = "./modules/vpc"

  cluster_name    = var.cluster_name
  vpc_cidr        = var.vpc_cidr
  azs             = var.azs
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  aws_region      = var.aws_region
}


module "ec2" {
  source = "./modules/ec2"

  vpc_id           = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnet_ids[0]
  key_name         = var.key_name
}

module "eks" {
  source = "./modules/eks"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  endpoint_public_access       = var.cluster_endpoint_public_access
  # endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  node_groups = var.node_groups

  additional_roles = [
    {
      rolearn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/DevOpsRole"
      username = "devops"
      groups   = ["system:masters"]
    }  ,
    {
      rolearn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/jenkins_ec2_role"
      username = "jenkins"
      groups   = ["jenkins-group"]

    }
  ]

  additional_users = []
}

module "addons" {
  source = "./modules/addons"

  cluster_name    = module.eks.cluster_name
  cluster_version = var.cluster_version
  aws_region      = var.aws_region

  node_group_ids = [for ng in module.eks.node_groups : ng.id]

  ebs_csi_role_arn             = module.eks.ebs_csi_role_arn
  alb_controller_role_arn      = module.eks.alb_controller_role_arn
  cluster_autoscaler_role_arn  = module.eks.cluster_autoscaler_role_arn
  vpc_id = module.vpc.vpc_id


  depends_on = [module.eks]
}

module "sonarqube" {
  
  source = "./modules/sonarqube"
  depends_on = [module.addons]
  
}
