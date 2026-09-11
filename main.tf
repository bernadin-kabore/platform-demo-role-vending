# ---------------------------------------------------------------------------
# The role vending machine.
#
# A team adds one file to roles/ describing what its repository's pipeline
# needs, opens a pull request, and on merge gets an AWS role federated to that
# repository -- with the ARN written back into that repository as an Actions
# variable, so there is no manual wiring step at the far end.
#
# Two directories, because the review boundary has to be a path. CODEOWNERS
# gates paths, not fields: a raw-policy key inside a team-owned file cannot be
# reviewed differently from the bundles beside it. So the escape hatch lives in
# exceptions/, which .github/CODEOWNERS assigns to the platform team, and
# roles/ stays self-service.
#
# Nothing here merges itself. A pull request against this repository is
# approved by a person, the same as any other change -- the permissions
# boundary caps how bad a mistake can be, but it cannot say whether the
# application should exist at all, and that is what the approval records.
# ---------------------------------------------------------------------------

locals {
  tags = {
    Project     = "platform-engineering-demo"
    Environment = "shared"
    ManagedBy   = "terraform"
    Component   = "role-vending-machine"
    Owner       = var.owner
  }

  declared_roles = {
    for f in fileset("${path.module}/roles", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(file("${path.module}/roles/${f}"))
  }

  declared_exceptions = {
    for f in fileset("${path.module}/exceptions", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(file("${path.module}/exceptions/${f}"))
  }

  roles = {
    for role_key, declaration in local.declared_roles :
    role_key => {
      github_owner = declaration.github_owner
      github_repo  = declaration.github_repo
      application  = try(declaration.application, null)
      grants       = try(declaration.grants, [])
      # Matched by filename. An exceptions/<key>.yaml grants to
      # roles/<key>.yaml and to nothing else.
      raw_statements = try(local.declared_exceptions[role_key].statements, [])
    }
  }
}

# An exception file whose name matches no role is not an error Terraform would
# otherwise report -- it simply grants nothing, silently, which is the worst
# possible outcome for a file someone wrote specifically to grant something.
check "every_exception_matches_a_role" {
  assert {
    condition = length(setsubtract(
      keys(local.declared_exceptions),
      keys(local.declared_roles),
    )) == 0
    error_message = format(
      "exceptions/ contains files with no matching roles/ file: %s. An exception is matched to a role by filename.",
      join(", ", setsubtract(keys(local.declared_exceptions), keys(local.declared_roles))),
    )
  }
}

# Publishing writes through one GitHub provider, which is configured for one
# owner. A role declared for a different owner would be vended in AWS and then
# have its ARN written into the wrong account's repository, or fail confusingly.
check "declared_owners_match_the_provider" {
  assert {
    condition = !var.publish_role_arn_to_repo || alltrue([
      for role in local.roles : role.github_owner == var.github_org
    ])
    error_message = "Every roles/*.yaml must declare github_owner matching var.github_org while publish_role_arn_to_repo is true."
  }
}

# The account holds exactly one OIDC provider per issuer URL, and
# platform-demo-terraform-modules/envs/dev already created this one. Reading it
# rather than declaring it is what keeps the two states from fighting: a second
# aws_iam_openid_connect_provider for the same URL is not a conflict Terraform
# can see at plan time, it is EntityAlreadyExists at apply time.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# The ceiling every role vended here is capped at, created and owned by
# envs/dev in the Terraform repository.
#
# Read, never declared, and that is the whole point. If this state owned the
# boundary, the pipeline running this configuration could raise its own ceiling
# in the same commit that used it. Instead the IAM policy on that pipeline's
# role pins this exact ARN with an iam:PermissionsBoundary condition, so a role
# created without it is refused by IAM rather than by review.
data "aws_iam_policy" "vended_role_boundary" {
  name = "${var.name_prefix}-vended-role-boundary"
}

module "vending" {
  # Pinned to a tag, not a branch. The module defines what self-service is able
  # to ask for, so moving this pin is a change to every role vended here --
  # which is why .github/CODEOWNERS gates this file, and why the pin is a
  # literal: Terraform does not allow a variable in a module source, so there
  # is no way to make it configurable and no way to move it silently.
  source = "../platform-demo-terraform-modules/modules/role-vending-machine"

  name_prefix              = var.name_prefix
  aws_region               = var.aws_region
  oidc_provider_arn        = data.aws_iam_openid_connect_provider.github.arn
  permissions_boundary_arn = data.aws_iam_policy.vended_role_boundary.arn
  roles                    = local.roles
  tags                     = local.tags
}

# The step an operator would otherwise do by hand after every apply: put the
# ARN into the consuming repository.
#
# A variable, not a secret. A role ARN is an identifier, not a credential --
# it is useless without the trust policy naming the one repository allowed to
# assume it, and that policy is what actually guards the role. Storing it as a
# secret would claim a confidentiality it does not have, hide it from the
# developer whose pipeline depends on it, and make a wrong value harder to
# diagnose because nobody can read back what was set.
resource "github_actions_variable" "role_arn" {
  for_each = var.publish_role_arn_to_repo ? local.roles : {}

  repository    = each.value.github_repo
  variable_name = "AWS_CI_ROLE_ARN"
  value         = module.vending.role_arns[each.key]
}
