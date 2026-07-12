# terraform.tfvars
# -----------------------------------------------------------------------------
# Actual variable values for the assessment environment.
# SECURITY: This file contains authorized IP addresses.
# Add to .gitignore if using a real IP. For assessment, placeholder IPs used.
# -----------------------------------------------------------------------------

aws_region = "ap-south-1"

students = [
  {
    id            = "student-01"
    authorized_ip = "182.48.215.138/32" # Replace with actual student-01 IP before apply
  },
  {
    id            = "student-02"
    authorized_ip = "182.48.215.138/32" # Replace with actual student-02 IP before apply
  }
]

fargate_capacity_provider = "FARGATE_SPOT"

log_retention_days  = 3
budget_limit_amount = "50.0"