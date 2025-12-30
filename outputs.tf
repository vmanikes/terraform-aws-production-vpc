output "vpc_id" {
  value       = aws_vpc.eks_vpc.id
  description = "ID of the VPC that got created"
}

# =============================================================================
# Subnet Outputs
# =============================================================================

output "public_subnet_ids" {
  value       = aws_subnet.public[*].id
  description = "List of public subnet IDs"
}

output "public_subnet_cidrs" {
  value       = aws_subnet.public[*].cidr_block
  description = "List of public subnet CIDR blocks"
}

output "private_subnet_ids" {
  value       = aws_subnet.private[*].id
  description = "List of private subnet IDs"
}

output "private_subnet_cidrs" {
  value       = aws_subnet.private[*].cidr_block
  description = "List of private subnet CIDR blocks"
}

output "isolated_subnet_ids" {
  value       = aws_subnet.isolated[*].id
  description = "List of isolated subnet IDs"
}

output "isolated_subnet_cidrs" {
  value       = aws_subnet.isolated[*].cidr_block
  description = "List of isolated subnet CIDR blocks"
}

output "availability_zones_used" {
  value       = distinct([for s in aws_subnet.public : s.availability_zone])
  description = "List of availability zones where subnets were created"
}

output "subnet_summary" {
  value = {
    public = {
      count       = length(aws_subnet.public)
      subnet_size = "/20 (4,096 IPs each)"
      purpose     = "ALB, NAT Gateway, Bastion"
    }
    private = {
      count       = length(aws_subnet.private)
      subnet_size = "/19 (8,192 IPs each)"
      purpose     = "EKS nodes, ECS, Apps"
    }
    isolated = {
      count       = length(aws_subnet.isolated)
      subnet_size = "/21 (2,048 IPs each)"
      purpose     = "RDS, ElastiCache"
    }
  }
  description = "Summary of subnet configuration"
}

# =============================================================================
# Gateway Outputs
# =============================================================================

output "internet_gateway_id" {
  value       = aws_internet_gateway.main.id
  description = "ID of the Internet Gateway"
}

output "nat_gateway_ids" {
  value       = aws_nat_gateway.main[*].id
  description = "List of NAT Gateway IDs"
}

output "nat_gateway_public_ips" {
  value       = aws_eip.nat[*].public_ip
  description = "List of NAT Gateway public IPs"
}

output "nat_gateway_mode" {
  value       = var.nat_gateway_mode
  description = "NAT Gateway availability mode (regional or per-az)"
}

# =============================================================================
# Route Table Outputs
# =============================================================================

output "public_route_table_id" {
  value       = aws_route_table.public.id
  description = "ID of the public route table"
}

output "private_route_table_ids" {
  value       = aws_route_table.private[*].id
  description = "List of private route table IDs (one per AZ)"
}

output "isolated_route_table_id" {
  value       = aws_route_table.isolated.id
  description = "ID of the isolated route table"
}

# =============================================================================
# Routing Summary
# =============================================================================

output "routing_summary" {
  value = {
    nat_gateway_mode = var.nat_gateway_mode
    public = {
      route_table_count = 1
      internet_route    = "0.0.0.0/0 → Internet Gateway"
      description       = "Direct internet access for ALBs, NAT GWs, Bastion"
    }
    private = {
      route_table_count = length(aws_route_table.private)
      nat_gateway_count = length(aws_nat_gateway.main)
      internet_route    = var.nat_gateway_mode == "regional" ? "0.0.0.0/0 → Regional NAT Gateway (HA)" : "0.0.0.0/0 → NAT Gateway (per-AZ)"
      description       = var.nat_gateway_mode == "regional" ? "Outbound via regional NAT (cost-optimized, HA)" : "Outbound via per-AZ NAT (maximum resilience)"
    }
    isolated = {
      route_table_count = 1
      internet_route    = "None - VPC local only"
      description       = "No internet access for RDS, ElastiCache (most secure)"
    }
  }
  description = "Summary of routing configuration"
}