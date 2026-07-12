# modules/networking/vpc.tf
# VPC and Internet Gateway — the foundational network boundary.

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    name = "${var.prefix}-vpc"
  }
}