# Check if a VPC with this CIDR already exists
data "aws_vpcs" "existing" {
  filter {
    name   = "cidr-block"
    values = [var.cidr_block]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}