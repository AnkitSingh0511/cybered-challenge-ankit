# terraform.tfvars
# -----------------------------------------------------------------------------
# Actual variable values for the assessment environment.
# SECURITY: This file contains authorized IP addresses.
# Add to .gitignore if using a real IP. For assessment, placeholder IPs used.
# -----------------------------------------------------------------------------

aws_region = "ap-south-1"

students = [{
  id            = "Gilles!"
  authorized_ip = "216.139.145.170/32" # Replace with actual student-01 IP before apply
  },
  {
    id            = "CARLOS"
    authorized_ip = "162.120.186.178/32" # Replace with actual student-02 IP before apply
  },
  {
    id            = "Ankit singh!"
    authorized_ip = "114.79.176.23/32" # Replace with actual student-02 IP before apply
  },
  {
    id            = "student-04"
    authorized_ip = "114.79.176.23/32" # Replace with actual student-02 IP before apply
  },
  {
    id            = "student-05"
    authorized_ip = "114.79.176.23/32" # Replace with actual student-02 IP before apply
  },
  {
    id            = "student-06"
    authorized_ip = "114.79.176.23/32" # Replace with actual student-02 IP before apply
  },
  {
    id            = "student-07"
    authorized_ip = "114.79.176.23/32" # Replace with actual student-02 IP before apply
  }
]

fargate_capacity_provider = "FARGATE_SPOT"

log_retention_days  = 3
budget_limit_amount = "50.0"