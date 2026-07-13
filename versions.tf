# versions.tf
# -----------------------------------------------------------------------------
# Terraform version constraint and AWS provider configuration.
# All resources inherit default_tags automatically via the AWS provider.
# -----------------------------------------------------------------------------

terraform {
  required_version = "~> 1.15.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      project      = "cybered-candidate-002"
      managed_by   = "terraform"
      environment  = "dev"
      candidate_id = "candidate-002"
    }
  }
}