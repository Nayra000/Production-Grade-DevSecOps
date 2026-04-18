variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for EKS"
  type        = string
}

variable "aws_region" {
  description = "AWS region for add-on deployment"
  type        = string
}

variable "node_group_ids" {
  description = "IDs of EKS node groups used to ensure add-on ordering"
  type        = list(string)
}

variable "ebs_csi_role_arn" {
  description = "IAM role ARN for the EBS CSI driver service account"
  type        = string
}

variable "alb_controller_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller service account"
  type        = string
}

variable "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for the Cluster Autoscaler service account"
  type        = string
}


variable "vpc_id" {
  description = "VPC ID where the EKS cluster is deployed (used for AWS Load Balancer Controller configuration)"
  type        = string
}