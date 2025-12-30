resource "aws_vpc" "eks_vpc" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  lifecycle {
    # postcondition has access to self.id, precondition does not
    postcondition {
      # Allow if the only VPC with this CIDR is the one we're managing
      condition     = length(data.aws_vpcs.existing.ids) == 0 || (length(data.aws_vpcs.existing.ids) == 1 && contains(data.aws_vpcs.existing.ids, self.id))
      error_message = "Another VPC with CIDR block ${var.cidr_block} already exists in this region (not managed by this Terraform configuration)."
    }
  }
}