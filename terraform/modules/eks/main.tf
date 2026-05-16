#################################################
# Security Groups
#################################################

# Control Plane Security Group
resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "EKS cluster security group"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.cluster_name}-cluster-sg" }
}

# Node Security Group
resource "aws_security_group" "nodes" {
  name        = "${var.cluster_name}-nodes-sg"
  description = "EKS node security group"
  vpc_id      = var.vpc_id

  # Allow all traffic within node group
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  # Allow control plane to reach nodes
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.cluster.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.cluster_name}-nodes-sg" }
}

# Allow nodes to reach control plane
resource "aws_security_group_rule" "nodes_to_cluster" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.nodes.id
  description              = "Allow nodes to reach API server"
}

resource "aws_security_group_rule" "jenkins_to_cluster" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = var.jenkins_security_group_id
  description              = "Allow Jenkins to reach API server"
  
}

#################################################
# EKS Cluster
#################################################
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = concat(var.private_subnet_ids, var.public_subnet_ids)
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.endpoint_public_access_cidrs
  }

  # Enable control plane logging
  # enabled_cluster_log_types = [
  #   "api",
  #   "audit",
  #   "authenticator",
  #   "controllerManager",
  #   "scheduler"
  # ]

  # encryption_config {
  #   provider {
  #     key_arn = aws_kms_key.eks.arn
  #   }
  #   resources = ["secrets"]
  # }

  # Ensure IAM role is created before cluster
  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSVPCResourceController,
    //aws_cloudwatch_log_group.eks,
  ]

  tags = {
    Name = var.cluster_name
  }
}

# CloudWatch Log Group for control plane logs
# resource "aws_cloudwatch_log_group" "eks" {
#   name              = "/aws/eks/${var.cluster_name}/cluster"
#   retention_in_days = 90

#   tags = { Name = "${var.cluster_name}-logs" }
# }

# KMS Key for secrets encryption
# resource "aws_kms_key" "eks" {
#   description             = "EKS cluster secrets encryption key"
#   deletion_window_in_days = 7
#   enable_key_rotation     = true

#   tags = { Name = "${var.cluster_name}-kms" }
# }

# resource "aws_kms_alias" "eks" {
#   name          = "alias/${var.cluster_name}"
#   target_key_id = aws_kms_key.eks.key_id
# }

#################################################
# Managed Node Groups
#################################################
resource "aws_eks_node_group" "main" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-${each.key}"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnet_ids

  instance_types = each.value.instance_types
  capacity_type  = each.value.capacity_type

  scaling_config {
    min_size     = each.value.min_size
    max_size     = each.value.max_size
    desired_size = each.value.desired_size
  }

  update_config {
    max_unavailable_percentage = 25
  }

  labels = each.value.labels

  dynamic "taint" {
    for_each = each.value.taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  # Use launch template for additional config
  launch_template {
    id      = aws_launch_template.node[each.key].id
    version = aws_launch_template.node[each.key].latest_version
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
  ]

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  tags = {
    "Name"                                          = "${var.cluster_name}-${each.key}"
    "k8s.io/cluster-autoscaler/enabled"             = "true"
    "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
  }
}

# Launch Template for nodes
resource "aws_launch_template" "node" {
  for_each = var.node_groups

  name_prefix = "${var.cluster_name}-${each.key}-lt"

 
  block_device_mappings {
    device_name = "/dev/xvda" # Amazon Linux 2; use /dev/nvme0n1 for Bottlerocket

    ebs {
      volume_size           = each.value.disk_size
      volume_type           = "gp3"
      encrypted             = true          # recommended
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  monitoring {
    enabled = true
  }

  vpc_security_group_ids = [aws_security_group.nodes.id]

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.cluster_name}-${each.key}-node"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
#################################################
# aws-auth ConfigMap
#################################################
# BEFORE — only patches, requires pre-existing ConfigMap

resource "kubernetes_config_map_v1" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode(concat(
      [{
        rolearn  = aws_iam_role.node.arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups   = ["system:bootstrappers", "system:nodes"]
      }],
      var.additional_roles
    ))
    mapUsers = yamlencode(var.additional_users)
  }

  depends_on = [aws_eks_cluster.main]
}