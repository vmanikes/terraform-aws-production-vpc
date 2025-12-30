# =============================================================================
# Subnet Configuration
# =============================================================================
# Layout Strategy (dynamic based on subnet counts):
# - Private subnets (/19, 8192 IPs) are allocated first
# - Public subnets (/20, 4096 IPs) follow immediately after private
# - Isolated subnets (/21, 2048 IPs) follow after public
#
# Dynamic offset calculation ensures no CIDR overlap regardless of subnet count.
# =============================================================================

locals {
  # Calculate VPC prefix length from CIDR block
  vpc_prefix_length = tonumber(split("/", var.cidr_block)[1])

  # Available AZs for distribution
  az_count           = length(data.aws_availability_zones.available.names)
  availability_zones = data.aws_availability_zones.available.names

  # Calculate total VPC IPs and per-subnet IPs
  vpc_total_ips     = pow(2, 32 - local.vpc_prefix_length)
  private_ips_each  = pow(2, 32 - 19) # /19 = 8192 IPs
  public_ips_each   = pow(2, 32 - 20) # /20 = 4096 IPs
  isolated_ips_each = pow(2, 32 - 21) # /21 = 2048 IPs

  # IPs required per "set" of subnets (one of each type)
  ips_per_set = local.private_ips_each + local.public_ips_each + local.isolated_ips_each # 14,336 IPs

  # Maximum sets that fit in the VPC (e.g., /16 = 65,536 IPs / 14,336 = 4.57 → 4 sets max)
  max_subnet_sets = floor(local.vpc_total_ips / local.ips_per_set)

  # Determine subnet counts:
  # - Default: use available AZs count, capped at max that fits (minimum 3)
  # - User override: respect user value (validated separately)
  default_subnet_count = min(max(3, local.az_count), local.max_subnet_sets)

  public_subnet_count   = coalesce(var.public_subnet_count, local.default_subnet_count)
  private_subnet_count  = coalesce(var.private_subnet_count, local.default_subnet_count)
  isolated_subnet_count = coalesce(var.isolated_subnet_count, local.default_subnet_count)

  # CIDR newbits calculations (relative to VPC CIDR)
  # For a /16 VPC: private=/19 (newbits=3), public=/20 (newbits=4), isolated=/21 (newbits=5)
  private_newbits  = 19 - local.vpc_prefix_length # /19 subnets
  public_newbits   = 20 - local.vpc_prefix_length # /20 subnets
  isolated_newbits = 21 - local.vpc_prefix_length # /21 subnets

  # Dynamic netnum offsets to prevent CIDR overlap
  # Each /19 occupies 2x /20 space or 4x /21 space
  # Each /20 occupies 2x /21 space
  private_netnum_offset = 0

  # Public starts after all private subnets
  # Each /19 = 2 /20s, so public offset = private_count * 2
  public_netnum_offset = local.private_subnet_count * 2

  # Isolated starts after all private and public subnets
  # Each /19 = 4 /21s, each /20 = 2 /21s
  isolated_netnum_offset = (local.private_subnet_count * 4) + (local.public_subnet_count * 2)

  # Calculate total IPs required for validation
  total_ips_required = (
    (local.private_subnet_count * local.private_ips_each) +
    (local.public_subnet_count * local.public_ips_each) +
    (local.isolated_subnet_count * local.isolated_ips_each)
  )
}

# =============================================================================
# Validation - Ensure subnet configuration fits within VPC
# =============================================================================

resource "terraform_data" "subnet_validation" {
  lifecycle {
    precondition {
      condition     = local.total_ips_required <= local.vpc_total_ips
      error_message = <<-EOT
        Subnet configuration exceeds VPC capacity!
        
        VPC CIDR: ${var.cidr_block} (${local.vpc_total_ips} IPs available)
        
        Requested subnets:
          - ${local.private_subnet_count} private (/19): ${local.private_subnet_count * local.private_ips_each} IPs
          - ${local.public_subnet_count} public (/20): ${local.public_subnet_count * local.public_ips_each} IPs
          - ${local.isolated_subnet_count} isolated (/21): ${local.isolated_subnet_count * local.isolated_ips_each} IPs
        
        Total required: ${local.total_ips_required} IPs
        
        Reduce subnet counts or use a larger VPC CIDR block.
        For a ${var.cidr_block} VPC, maximum ${local.max_subnet_sets} subnets of each type can be created.
      EOT
    }
  }
}

# =============================================================================
# Public Subnets (/20 - 4,096 IPs each)
# Purpose: ALB, NAT Gateway, Bastion hosts
# =============================================================================

resource "aws_subnet" "public" {
  count = local.public_subnet_count

  enable_resource_name_dns_a_record_on_launch = true
  vpc_id                                      = aws_vpc.eks_vpc.id
  cidr_block                                  = cidrsubnet(var.cidr_block, local.public_newbits, local.public_netnum_offset + count.index)
  availability_zone                           = local.availability_zones[count.index % local.az_count]
  map_public_ip_on_launch                     = true

  tags = {
    Name                     = "public-${local.availability_zones[count.index % local.az_count]}-${count.index + 1}"
    Type                     = "public"
    "kubernetes.io/role/elb" = "1"
  }
}

# =============================================================================
# Private Subnets (/19 - 8,192 IPs each)
# Purpose: EKS nodes, ECS tasks, application workloads
# =============================================================================

resource "aws_subnet" "private" {
  count = local.private_subnet_count

  enable_resource_name_dns_a_record_on_launch = true
  vpc_id                                      = aws_vpc.eks_vpc.id
  cidr_block                                  = cidrsubnet(var.cidr_block, local.private_newbits, local.private_netnum_offset + count.index)
  availability_zone                           = local.availability_zones[count.index % local.az_count]

  tags = {
    Name                              = "private-${local.availability_zones[count.index % local.az_count]}-${count.index + 1}"
    Type                              = "private"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# =============================================================================
# Isolated Subnets (/21 - 2,048 IPs each)
# Purpose: RDS databases, ElastiCache, other data stores (no internet access)
# =============================================================================

resource "aws_subnet" "isolated" {
  count = local.isolated_subnet_count

  enable_resource_name_dns_a_record_on_launch = true
  vpc_id                                      = aws_vpc.eks_vpc.id
  cidr_block                                  = cidrsubnet(var.cidr_block, local.isolated_newbits, local.isolated_netnum_offset + count.index)
  availability_zone                           = local.availability_zones[count.index % local.az_count]

  tags = {
    Name = "isolated-${local.availability_zones[count.index % local.az_count]}-${count.index + 1}"
    Type = "isolated"
  }
}

