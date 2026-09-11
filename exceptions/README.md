# exceptions/

Raw IAM statements for the cases the bundle catalogue does not cover.

This is a separate directory from `../roles/` for one reason: CODEOWNERS gates
paths, not fields. A `raw_policy:` key inside a team's own file could not be
reviewed differently from the bundles beside it, so the escape hatch would have
been self-service in practice no matter what the documentation claimed.
`.github/CODEOWNERS` assigns this directory to the platform team, which makes
the review requirement real rather than stated.

A file here is matched to a role by filename: `exceptions/checkout-platform.yaml`
adds statements to the role declared in `roles/checkout-platform.yaml`. An
exception whose name matches no role fails the plan rather than silently
granting nothing.

```yaml
# exceptions/checkout-platform.yaml
statements:
  - sid: PublishToEventStream
    actions:
      - kinesis:PutRecord
    resources:
      - arn:aws:kinesis:us-east-1:382334305409:stream/checkout-events
```

Two things still constrain what can be written here. The permissions boundary
applies to these statements exactly as it does to a bundle, so an exception
cannot reach a service the platform does not vend -- if the action is outside
the boundary's Allow set, granting it here changes nothing at runtime and the
pipeline will still get AccessDenied. And `iam:` actions are rejected at plan
time, so that failure mode is reported when the pull request is opened rather
than discovered in a job log.

Widening the boundary to admit a new service is a separate change, in
`platform-demo-terraform-modules/modules/vended-role-boundary`, applied by
`envs/dev`. It deliberately cannot be made from this repository: the pipeline
that vends roles must not be able to raise the ceiling it vends them under.
