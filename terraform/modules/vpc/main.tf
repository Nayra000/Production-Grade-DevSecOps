# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true   # required for EKS
  enable_dns_support   = true   # required for EKS

  tags = {
    Name = "${var.cluster_name}-vpc"
    # EKS needs these tags to discover the VPC
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# Internet Gateway — for public subnets
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.cluster_name}-igw"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count = length(var.public_subnets)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.cluster_name}-public-${var.azs[count.index]}"
    # Required for ALB controller to discover public subnets
    "kubernetes.io/role/elb"                          = "1"
    "kubernetes.io/cluster/${var.cluster_name}"       = "shared"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count = length(var.private_subnets)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name = "${var.cluster_name}-private-${var.azs[count.index]}"
    # Required for ALB controller to discover private subnets
    "kubernetes.io/role/internal-elb"                 = "1"
    "kubernetes.io/cluster/${var.cluster_name}"       = "shared"
    # Required for Karpenter node discovery
    "karpenter.sh/discovery"                          = var.cluster_name
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.cluster_name}-nat-eip-${var.azs[0]}"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {

  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.cluster_name}-nat-${var.azs[0]}"
  }

  depends_on = [aws_internet_gateway.main]
}

# Route Table — Public (routes to IGW)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.cluster_name}-public-rt"
  }
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  count = length(var.public_subnets)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route Tables — Private (one per AZ, each routes to its NAT GW)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.cluster_name}-private-rt"
  }
}

# Associate private subnets with private route tables
resource "aws_route_table_association" "private" {
  count = length(var.private_subnets)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# # VPC Endpoints (optional but recommended — reduces NAT costs)
# # S3 Gateway Endpoint — free, reduces NAT traffic for S3/ECR
# resource "aws_vpc_endpoint" "s3" {
#   vpc_id            = aws_vpc.main.id
#   service_name      = "com.amazonaws.${var.aws_region}.s3"
#   vpc_endpoint_type = "Gateway"
#   route_table_ids   = aws_route_table.private[*].id

#   tags = {
#     Name = "${var.cluster_name}-s3-endpoint"
#   }
# }

# # ECR endpoints (interface) — needed if nodes are in private subnet
# resource "aws_vpc_endpoint" "ecr_api" {
#   vpc_id              = aws_vpc.main.id
#   service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
#   vpc_endpoint_type   = "Interface"
#   subnet_ids          = aws_subnet.private[*].id
#   security_group_ids  = [aws_security_group.vpc_endpoints.id]
#   private_dns_enabled = true

#   tags = { Name = "${var.cluster_name}-ecr-api-endpoint" }
# }

# resource "aws_vpc_endpoint" "ecr_dkr" {
#   vpc_id              = aws_vpc.main.id
#   service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
#   vpc_endpoint_type   = "Interface"
#   subnet_ids          = aws_subnet.private[*].id
#   security_group_ids  = [aws_security_group.vpc_endpoints.id]
#   private_dns_enabled = true

#   tags = { Name = "${var.cluster_name}-ecr-dkr-endpoint" }
# }

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.cluster_name}-vpc-endpoints-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = { Name = "${var.cluster_name}-vpc-endpoints-sg" }
}