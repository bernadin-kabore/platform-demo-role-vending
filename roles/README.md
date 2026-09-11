# roles/

One file per GitHub repository that needs an AWS identity. Adding a file here
is self-service: open a pull request, and on merge the repository gets a role
it can assume from its own Actions workflow. You do not need platform-team
review to add or change a file in this directory.

A pull request here still needs a human to approve it -- nothing in this
repository merges itself. What self-service means is that the approver does not
have to be the platform team, and does not have to review IAM: every role
vended from here is capped by a permissions boundary it cannot opt out of, and
every grant comes from a fixed catalogue of bundles rather than hand-written
policy. No file in this directory can express an identity that escapes the
ceiling -- see `../README.md` for what that ceiling is and where it lives.

## The file

Name it after the application. The filename becomes the role key, the role is
created as `platform-demo-<filename>-ci`, and an `exceptions/<filename>.yaml`
is matched to it by that same name.

If Backstage created the application, this file was written for you and you are
reading this because you are changing it -- most often to add a service.

```yaml
# roles/checkout-platform.yaml
github_owner: bernadin-kabore
github_repo: checkout-platform-source

# Optional. ECR repositories are named <application>-<service>; this defaults
# to the filename, which is normally what you want.
application: checkout-platform

grants:
  - bundle: ecr-push
    services: [auth, payments]

  - bundle: s3-readwrite
    bucket: checkout-platform-uploads
    prefix: incoming/
```

The role trusts `refs/heads/main` of that repository and nothing else. A pull
request build cannot assume it; that is intentional, because a fork's pull
request would otherwise be able to.

## The bundle catalogue

| Bundle | Parameters | Grants |
|---|---|---|
| `ecr-push` | `services` | Push and read the application's own image repositories, and nothing else in the registry |
| `s3-readwrite` | `bucket`, optional `prefix` | List the bucket; get, put and delete objects under the prefix |
| `sqs-consume` | `queue` | Receive, delete and inspect messages on one queue |
| `dynamodb-readwrite` | `table` | Item and query operations on one table and its indexes |

If none of these fits, the grant needs a raw IAM statement, which lives in
`../exceptions/` and is reviewed by the platform team. Ask rather than
contorting a bundle into something it was not meant to express -- and if the
same request arrives twice, that is a sign the catalogue is missing a bundle.
