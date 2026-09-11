# Deliberately separate state from envs/dev.
#
# Onboarding a repository must not produce a plan whose blast radius includes
# the VPC and the EKS control plane. Before this root existed, adding an
# application meant editing envs/dev/terraform.tfvars -- the same state that
# owns the cluster -- so the smallest possible change, granting one repository
# the right to push one image, was reviewed against a plan that could also
# replace the control plane.
#
# terraform init -backend-config=backend.hcl
terraform {
  backend "s3" {
    # bucket         = "REPLACE-WITH-STATE-BUCKET"
    # key            = "platform-demo/role-vending/terraform.tfstate"
    # region         = "us-east-1"
    # dynamodb_table = "REPLACE-WITH-LOCK-TABLE"
    # encrypt        = true
  }
}
