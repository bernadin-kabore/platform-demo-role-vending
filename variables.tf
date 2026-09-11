variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for vended role names. Matches cluster_name in envs/dev so the roles sort together."
  type        = string
  default     = "platform-demo"
}

variable "github_org" {
  description = "The GitHub owner every vended repository belongs to. Publishing the role ARN back into a repository uses one provider, so one owner."
  type        = string
}

variable "publish_role_arn_to_repo" {
  description = <<-DESC
    Write each vended ARN into its own repository as the AWS_CI_ROLE_ARN
    Actions secret, closing the loop that would otherwise be a manual step
    after every apply. Set false to run the AWS half without a GitHub token.
  DESC
  type        = bool
  default     = true
}

variable "owner" {
  type    = string
  default = "bernadin-kabore"
}
