# backend.tf
# -----------------------------------------------------------------------------
# Remote state configuration using pre-existing S3 backend.
# State locking via S3 native lockfile (Terraform 1.10+).
# No bootstrap required — bucket is pre-provisioned by the assessment team.
# -----------------------------------------------------------------------------

terraform {
  backend "s3" {
    bucket       = "cybered-assessment-tfstate-150105760360-ap-south-1"
    key          = "candidates/candidate-002/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}