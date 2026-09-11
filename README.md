# Role vending machine

When an application needs to touch AWS from its pipeline — to push a container
image, read a bucket, drain a queue — it needs an AWS identity. This repository
is how it gets one.

A team adds one file describing what its pipeline needs, opens a pull request,
and on merge the role exists and its ARN is written back into the application's
own repository. No long-lived access key is created at any point, nobody hand
writes IAM, and nobody files a ticket asking someone with console access to do
it for them.

Most of the time nobody adds that file by hand either: creating an application
in Backstage opens the pull request for you, already filled in.

## How a role comes to exist

1. A developer creates an application in Backstage.
2. The scaffolder opens a pull request here adding `roles/<application>.yaml`,
   listing the services that application declared.
3. A human reviews and merges it. The `plan` workflow has already posted, as a
   comment, a plain-language summary of exactly what the role will be allowed
   to do.
4. The `apply` workflow creates the role and the image repositories, writes
   `AWS_CI_ROLE_ARN` into the application's source repository, and re-triggers
   its pipeline so the first build starts on its own.

Between steps 1 and 4 the application's pipeline runs its tests and scans but
skips the build, and says so in its run summary. That is expected: there is no
identity to push with yet.

## Why a human still merges

Nothing here merges itself, and that is deliberate.

The permissions boundary described below caps how *bad* a mistake can be. It
cannot say whether an application should exist, who owns it, or whether it
should be accruing cloud resources at all — none of those are IAM questions.
The merge is where a person records that judgement.

It is also the case that a bot merging its own pull request needs an exemption
from the branch ruleset, and this platform removed every one of those on
purpose. A self-merging automation is that exemption under another name.

What the boundary buys is not the removal of the human, but the removal of the
*expertise* the human needs. A reviewer does not have to audit IAM or reason
about escalation paths — those are foreclosed before the pull request is
opened. They have to decide whether this application should exist. That takes
seconds, and it happens once per application, not once per deploy.

## What keeps self-service safe

**A permissions boundary on every vended role.** A boundary is a ceiling, not a
grant: a role's effective permissions are the intersection of its policy and
the boundary. Terraform attaches it unconditionally, and no declaration here
can express a role without one. The boundary denies `iam:`, `organizations:`,
role chaining, and all access to EKS and EC2 — a pipeline publishes artifacts,
Argo CD deploys them, and a CI role that can reach the cluster API collapses
the separation the signed-image chain depends on. It also region-locks every
service it vends.

The boundary is **not defined in this repository**. It lives in
`platform-demo-terraform-modules/modules/vended-role-boundary`, is created by
`envs/dev`, and is read here by data source. If this state owned it, the
pipeline that vends roles could raise its own ceiling in the same commit that
used it.

**IAM refuses an unbounded role even if this pipeline asks for one.** The role
this repository's `apply` workflow assumes is allowed `iam:CreateRole` only
under a condition pinning `iam:PermissionsBoundary` to that exact policy ARN. A
create call that omits the boundary, or names a different one, fails at AWS.
That is what makes the credential here survivable despite being the most
privileged on the platform.

**A catalogue instead of raw IAM.** Files in `roles/` select from named,
parameterised bundles. Action lists live in one reviewed place, so a bundle
that turns out to be missing a permission gets fixed once for everyone rather
than copied wrong into the next file.

The escape hatch for what the catalogue does not cover is `exceptions/`, which
`.github/CODEOWNERS` assigns to the platform team. It is a separate directory
rather than a field inside the requesting team's own file because CODEOWNERS
gates paths, not fields — a `raw_policy:` key beside the bundles could not have
been reviewed differently from them.

## Layout

| Path | What it is | Who reviews |
|---|---|---|
| `roles/` | One file per repository needing an identity | Any platform-team approver |
| `exceptions/` | Raw IAM for what bundles cannot express | Platform team, via CODEOWNERS |
| `main.tf` | Root config, including the pinned module ref | Platform team, via CODEOWNERS |
| `.github/` | The pipeline holding the role-creating credential | Platform team, via CODEOWNERS |

The vending logic itself is not here. It is
`platform-demo-terraform-modules//modules/role-vending-machine`, pinned in
`main.tf` to a tag. Terraform does not allow a variable in a module source, so
the pin is a literal and cannot be moved silently.

## Running it by hand

The pipeline does this on merge; these are the same commands for a local plan.

```bash
cp terraform.tfvars.example terraform.tfvars   # then edit github_org and owner

# backend.hcl mirrors envs/dev with
#   key = platform-demo/role-vending/terraform.tfstate
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
```

Writing the ARN into each repository needs `GITHUB_TOKEN` in the environment —
a fine-grained PAT or GitHub App installation token with Variables write on the
repositories being vended for. To run the AWS half without one:

```bash
terraform plan -var publish_role_arn_to_repo=false -out=tfplan
```

`terraform output granted_statements` shows what every role can actually do,
flattened, so a diff reads as a one-line permission change rather than
re-rendered JSON.

## Before the first apply

Three things have to exist, and none of them can be created from here:

- **The permissions boundary and both CI roles**, from `envs/dev` in the
  Terraform repository, with `role_vending_repo` set in its tfvars. The vending
  machine cannot vend its own identity — something outside it has to go first.
- **The module tag.** `main.tf` pins `?ref=rvm-v1`; that tag has to be pushed on
  `platform-demo-terraform-modules` or `terraform init` cannot resolve it.
- **Repository variables and secrets here**: `AWS_ROLE_ARN` and
  `AWS_PLAN_ROLE_ARN` from the `envs/dev` outputs of the same name, and
  `PLATFORM_GITHUB_TOKEN` as a secret.
