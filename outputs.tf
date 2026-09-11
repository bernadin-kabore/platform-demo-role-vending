output "role_arns" {
  description = "Vended role ARNs by role key. Already written into each repository unless publish_role_arn_to_repo is false."
  value       = module.vending.role_arns
}

output "permissions_boundary_arn" {
  value = module.vending.permissions_boundary_arn
}

output "granted_statements" {
  description = "What each role can do, flattened so a pull request diff is readable."
  value       = module.vending.granted_statements
}

output "vended_repositories" {
  description = <<-DESC
    Role key to owner/repository, for the apply workflow to dispatch a first
    build into. Kicking that build is an event, not desired state, so it is a
    step in the pipeline rather than a Terraform resource -- there is nothing
    for Terraform to converge on and re-running an apply must not re-trigger
    every application.
  DESC
  value = {
    for role_key, role in local.roles :
    role_key => "${role.github_owner}/${role.github_repo}"
  }
}
