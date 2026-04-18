variable "vpc_id" {
  description = "VPC ID for the EKS cluster"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID for the EC2 instance"
  type        = string
}

variable "key_name" {
  description = "Key pair name for SSH access to the EC2 instance"
  type        = string
}