# modules/networking/security_groups.tf
# Per-student security groups enforce zero-trust isolation.
# Each student's SG:
#   Inbound:  Only from their own authorized_ip on KasmWeb port 6901
#   Outbound: Only 80/443 to internet + 6379 to cache SG
#             Explicitly NO egress to VPC CIDR — blocks inter-student traffic
#
# Cache security group:
#   Inbound:  Only from student SG IDs on port 6379
#   Outbound: None — cache never initiates connections

# ---------------------------------------------------------------------------
# Per-Student Security Groups
# ---------------------------------------------------------------------------
resource "aws_security_group" "student" {
  for_each = var.sanitized_students

  name        = "${var.prefix}-sg-${each.value.id}"
  description = "Zero-trust SG for ${each.value.id}. Inbound locked to authorized IP only."
  vpc_id      = aws_vpc.main.id

  tags = {
    name  = "${var.prefix}-sg-${each.value.id}"
    owner = each.value.id
  }
}

# Inbound — KasmWeb desktop UI (HTTPS) from authorized IP only
resource "aws_vpc_security_group_ingress_rule" "student_kasm" {
  for_each = var.sanitized_students

  security_group_id = aws_security_group.student[each.key].id
  description       = "Allow KasmWeb HTTPS desktop access from authorized IP only."
  from_port         = 6901
  to_port           = 6901
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value.authorized_ip

  tags = {
    name  = "${var.prefix}-ingress-kasm-${each.value.id}"
    owner = each.value.id
  }
}

resource "aws_vpc_security_group_ingress_rule" "student_nginx" {
  for_each = var.sanitized_students

  security_group_id = aws_security_group.student[each.key].id
  description       = "Allow nginx server access from authorized IP only."
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value.authorized_ip

  tags = {
    name  = "${var.prefix}-ingress-nginx-${each.value.id}"
    owner = each.value.id
  }
}

# Outbound — HTTPS to internet (ECR image pull, AWS API calls)
resource "aws_vpc_security_group_egress_rule" "student_https" {
  for_each = var.sanitized_students

  security_group_id = aws_security_group.student[each.key].id
  description       = "Allow HTTPS outbound for ECR pulls and AWS API calls."
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    name  = "${var.prefix}-egress-https-${each.value.id}"
    owner = each.value.id
  }
}

# Outbound — HTTP to internet (package updates inside KasmWeb desktop)
resource "aws_vpc_security_group_egress_rule" "student_http" {
  for_each = var.sanitized_students

  security_group_id = aws_security_group.student[each.key].id
  description       = "Allow HTTP outbound for package updates inside KasmWeb."
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    name  = "${var.prefix}-egress-http-${each.value.id}"
    owner = each.value.id
  }
}

# Outbound — Redis/Valkey to cache SG on port 6379 (deferred — wired now for correctness)
resource "aws_vpc_security_group_egress_rule" "student_cache" {
  for_each = var.sanitized_students

  security_group_id            = aws_security_group.student[each.key].id
  description                  = "Allow outbound to ElastiCache Valkey on port 6379."
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.cache.id

  tags = {
    name  = "${var.prefix}-egress-cache-${each.value.id}"
    owner = each.value.id
  }
}

# ---------------------------------------------------------------------------
# Cache Security Group
# ---------------------------------------------------------------------------
resource "aws_security_group" "cache" {
  name        = "${var.prefix}-sg-cache"
  description = "SG for ElastiCache Valkey. Accepts only from student SGs on 6379."
  vpc_id      = aws_vpc.main.id

  tags = {
    name = "${var.prefix}-sg-cache"
  }
}

# Inbound — Accept Redis connections from each student SG
resource "aws_vpc_security_group_ingress_rule" "cache_from_student" {
  for_each = var.sanitized_students

  security_group_id            = aws_security_group.cache.id
  description                  = "Allow Redis inbound from ${each.value.id} task SG."
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.student[each.key].id

  tags = {
    name  = "${var.prefix}-ingress-cache-from-${each.value.id}"
    owner = each.value.id
  }
}