variable "vpc_cidr"        { type = string }
variable "cluster_name"    { type = string }
variable "azs"             { type = list(string) }
variable "public_subnets"  { type = list(string) }
variable "private_subnets" { type = list(string) }
variable "aws_region"      { type = string }