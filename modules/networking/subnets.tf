# modules/networking/subnets.tf
# One dedicated /28 public subnet per student + one static cache subnet.
# All subnets are public — NAT Gateway is banned by spec.
# Fargate tasks use assign_public_ip=ENABLED for internet access.

resource "aws_subnet" "student" {
  for_each = var.sanitized_students

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = false

  tags = {
    name  = "${var.prefix}-subnet-${each.value.id}"
    owner = each.value.id
  }
}

resource "aws_subnet" "cache" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.cache_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = false

  tags = {
    name = "${var.prefix}-subnet-cache"
  }
}