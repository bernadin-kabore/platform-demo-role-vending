terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    github = {
      source  = "integrations/github"
      version = ">= 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Reads the token from the GITHUB_TOKEN env var -- a fine-grained PAT (or a
# GitHub App installation token) with "Secrets: read/write" on the repositories
# being vended for. Never pass it as a Terraform variable or tfvars value; it
# would end up in state and in the plan output.
provider "github" {
  owner = var.github_org
}
