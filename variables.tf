variable "cidr_block" {
  type        = string
  description = "CIDR block for the VPC"

  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "Must be a valid CIDR block (e.g., 10.0.0.0/16)."
  }
}

variable "public_subnet_count" {
  type        = number
  description = "Number of public subnets (/20, 4096 IPs each). Minimum 3, distributed across AZs. Used for ALB, NAT GW, bastion."
  default     = null # Will use number of available AZs (minimum 3)

  validation {
    condition     = var.public_subnet_count == null || var.public_subnet_count >= 3
    error_message = "public_subnet_count must be at least 3."
  }
}

variable "private_subnet_count" {
  type        = number
  description = "Number of private subnets (/19, 8192 IPs each). Minimum 3, distributed across AZs. Used for EKS nodes, ECS, apps."
  default     = null # Will use number of available AZs (minimum 3)

  validation {
    condition     = var.private_subnet_count == null || var.private_subnet_count >= 3
    error_message = "private_subnet_count must be at least 3."
  }
}

variable "isolated_subnet_count" {
  type        = number
  description = "Number of isolated subnets (/21, 2048 IPs each). Minimum 3, distributed across AZs. Used for RDS, ElastiCache."
  default     = null # Will use number of available AZs (minimum 3)

  validation {
    condition     = var.isolated_subnet_count == null || var.isolated_subnet_count >= 3
    error_message = "isolated_subnet_count must be at least 3."
  }
}

variable "nat_gateway_mode" {
  type        = string
  description = "NAT Gateway availability mode: 'regional' (single HA NAT, cost-optimized) or 'per-az' (one NAT per AZ, maximum resilience)."
  default     = "regional"

  validation {
    condition     = contains(["regional", "per-az"], var.nat_gateway_mode)
    error_message = "nat_gateway_mode must be either 'regional' or 'per-az'."
  }
}
