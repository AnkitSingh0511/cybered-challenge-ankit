# modules/networking/route_tables.tf
# One shared public route table for all subnets.
# Default route sends all internet-bound traffic via the IGW.
# Isolation is enforced by security groups — not routing.

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    name = "${var.prefix}-rt-public"
  }
}

resource "aws_route" "internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id

  depends_on = [aws_internet_gateway.main]
}

# Associate every student subnet with the public route table
resource "aws_route_table_association" "student" {
  for_each = var.sanitized_students

  subnet_id      = aws_subnet.student[each.key].id
  route_table_id = aws_route_table.public.id
}

# Associate cache subnet with the public route table
resource "aws_route_table_association" "cache" {
  subnet_id      = aws_subnet.cache.id
  route_table_id = aws_route_table.public.id
}