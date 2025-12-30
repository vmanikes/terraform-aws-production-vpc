# =============================================================================
# Internet Gateway
# =============================================================================
# Single IGW for the VPC - provides internet access for public subnets

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "eks-vpc-igw"
  }
}

# =============================================================================
# NAT Gateway Configuration
# =============================================================================
# Two modes:
# - regional: Single NAT Gateway with regional HA (cost-optimized)
# - per-az: One NAT Gateway per AZ (maximum resilience, traffic stays in-AZ)
#
# See: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway#availability_mode-1

locals {
  is_regional_nat   = var.nat_gateway_mode == "regional"
  nat_gateway_count = local.is_regional_nat ? 1 : local.public_subnet_count
}

# =============================================================================
# Elastic IPs for NAT Gateways
# =============================================================================

resource "aws_eip" "nat" {
  count  = local.nat_gateway_count
  domain = "vpc"

  tags = {
    Name = local.is_regional_nat ? "nat-eip-regional" : "nat-eip-${local.availability_zones[count.index % local.az_count]}-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}

# =============================================================================
# NAT Gateways
# =============================================================================

resource "aws_nat_gateway" "main" {
  count = local.nat_gateway_count

  allocation_id     = aws_eip.nat[count.index].id
  availability_mode = local.is_regional_nat ? "regional" : "zone"
  # Regional mode: uses vpc_id (AWS manages subnet placement)
  # Zone mode: uses subnet_id (you specify which subnet)
  vpc_id    = local.is_regional_nat ? aws_vpc.eks_vpc.id : null
  subnet_id = local.is_regional_nat ? null : aws_subnet.public[count.index].id

  tags = {
    Name = local.is_regional_nat ? "nat-gw-regional" : "nat-gw-${local.availability_zones[count.index % local.az_count]}-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}

# =============================================================================
# Public Route Table
# =============================================================================
# Single route table for all public subnets
# Routes: local + 0.0.0.0/0 → IGW

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "public-rt"
    Type = "public"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  count = local.public_subnet_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# =============================================================================
# Private Route Tables
# =============================================================================
# Regional mode: One route table for all private subnets → single regional NAT
# Per-AZ mode: Each AZ gets its own route table → its own zonal NAT Gateway
# Routes: local + 0.0.0.0/0 → NAT Gateway

resource "aws_route_table" "private" {
  count = local.is_regional_nat ? 1 : local.private_subnet_count

  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = local.is_regional_nat ? "private-rt" : "private-rt-${local.availability_zones[count.index % local.az_count]}-${count.index + 1}"
    Type = "private"
  }
}

resource "aws_route" "private_nat" {
  count = local.is_regional_nat ? 1 : local.private_subnet_count

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  # Regional mode: all traffic goes through the single regional NAT Gateway
  # Per-AZ mode: traffic goes through the NAT Gateway in the same AZ
  nat_gateway_id = local.is_regional_nat ? aws_nat_gateway.main[0].id : aws_nat_gateway.main[count.index % local.nat_gateway_count].id
}

resource "aws_route_table_association" "private" {
  count = local.private_subnet_count

  subnet_id = aws_subnet.private[count.index].id
  # Regional mode: all subnets use the single route table
  # Per-AZ mode: each subnet uses its corresponding route table
  route_table_id = local.is_regional_nat ? aws_route_table.private[0].id : aws_route_table.private[count.index].id
}

# =============================================================================
# Isolated Route Table
# =============================================================================
# Single route table for all isolated subnets - NO internet access
# Routes: local only (implicit VPC CIDR route)
# This is the most secure tier - only VPC-internal communication

resource "aws_route_table" "isolated" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "isolated-rt"
    Type = "isolated"
  }
}

# No routes added - only the implicit local route exists
# This ensures isolated subnets have zero internet connectivity

resource "aws_route_table_association" "isolated" {
  count = local.isolated_subnet_count

  subnet_id      = aws_subnet.isolated[count.index].id
  route_table_id = aws_route_table.isolated.id
}

# =============================================================================
# Isolated Subnet NACL
# =============================================================================
# Restrictive NACL for isolated subnets:
# - Allow traffic only from/to VPC CIDR (10.0.0.0/16)
# - Deny all other traffic (0.0.0.0/0)

resource "aws_network_acl" "isolated" {
  vpc_id     = aws_vpc.eks_vpc.id
  subnet_ids = aws_subnet.isolated[*].id

  tags = {
    Name = "isolated-nacl"
    Type = "isolated"
  }
}

# -----------------------------------------------------------------------------
# Ingress Rules
# -----------------------------------------------------------------------------

# Allow inbound traffic from VPC CIDR
resource "aws_network_acl_rule" "isolated_ingress_allow_vpc" {
  network_acl_id = aws_network_acl.isolated.id
  rule_number    = 100
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "10.0.0.0/16"
}

# Deny all other inbound traffic
resource "aws_network_acl_rule" "isolated_ingress_deny_all" {
  network_acl_id = aws_network_acl.isolated.id
  rule_number    = 200
  egress         = false
  protocol       = "-1"
  rule_action    = "deny"
  cidr_block     = "0.0.0.0/0"
}

# -----------------------------------------------------------------------------
# Egress Rules
# -----------------------------------------------------------------------------

# Allow outbound traffic to VPC CIDR
resource "aws_network_acl_rule" "isolated_egress_allow_vpc" {
  network_acl_id = aws_network_acl.isolated.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "10.0.0.0/16"
}

# Deny all other outbound traffic
resource "aws_network_acl_rule" "isolated_egress_deny_all" {
  network_acl_id = aws_network_acl.isolated.id
  rule_number    = 200
  egress         = true
  protocol       = "-1"
  rule_action    = "deny"
  cidr_block     = "0.0.0.0/0"
}

