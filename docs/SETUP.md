# Setup

## Prerequisites

- Terraform 1.11+ (verified with 1.13.4) — S3-native state locking needs ≥ 1.11
- AWS CLI v2
- Three AWS accounts (or one account reused for all three profiles while
  bootstrapping the demo)
- Optional, for the quality gates: `pre-commit` (fmt/validate/docs/tflint),
  `terraform-docs`, `tflint` — see `docs/RESEARCH.md`

## Named profiles

Create ~/.aws/credentials with three profiles:

    [dev]
    aws_access_key_id = AKIA...
    aws_secret_access_key = ...

    [staging]
    ...

    [prod]
    ...

Until real accounts exist, all three profiles may point at the same account —
the multi-account structure is coded regardless.

The profiles need read/write on the state bucket and its lockfiles — with
least privilege that is `s3:GetObject`/`s3:PutObject` on the state keys and
`*.tflock` keys, plus `s3:ListBucket` (no DynamoDB permissions are needed:
locking is S3-native via a lockfile).

Each component's `backend.tf` and its `terraform_remote_state` data source
carry an explicit `profile` (dev / staging / prod), so `terraform init` and
state reads resolve that environment's account directly — no reliance on your
`default` credential chain. With three real accounts this is required; with
the single-account stand-in it works unchanged.

## Bootstrap (once)

    cd environments/bootstrap
    terraform init && terraform apply

Creates the tfstate-<env>-kartik-2026 state buckets in each account profile. Locking is
S3-native (a lockfile lives in the bucket), so no DynamoDB table is created.

The bucket names (`tfstate-dev-kartik-2026`, `tfstate-staging-kartik-2026`, `tfstate-prod-kartik-2026`) must be
globally unique. If bootstrap fails with a `BucketAlreadyExists` /
`BucketAlreadyOwnedByYou` error, rename them in `environments/bootstrap/main.tf`
and the matching `backend.tf` files.

## Apply (dev only for the live demo)

    cd environments/dev/network   && terraform init && terraform apply -auto-approve
    cd environments/dev/database  && terraform init && terraform apply -auto-approve
    cd environments/dev/ecs       && terraform init && terraform apply -auto-approve

## Cost

Dev, while running ≈ $70/mo (1 NAT+EIP ≈ $34, RDS micro ≈ $13, ALB ≈ $16,
Fargate ≈ $5). **Destroy after the demo.**

## Teardown

    cd environments/dev/ecs       && terraform destroy -auto-approve
    cd environments/dev/database  && terraform destroy -auto-approve
    cd environments/dev/network   && terraform destroy -auto-approve

`staging` and `prod` are coded but not applied in the demo. If you ever do
apply them, `prod/database` has `deletion_protection = true` (by design), so
`make destroy` will stop at that component — remove the flag in
`environments/prod/database/terraform.tfvars` and re-run before tearing it down.

## Quality gates (local)

    pre-commit install          # one-time; runs fmt/validate/docs/tflint on every commit
    pre-commit run --all-files  # run all hooks explicitly

The hooks run `terraform fmt`, `terraform validate` (with `-backend=false`, so
they need no credentials), `terraform-docs` on `modules/*`, and `tflint`.
CI runs the same checks on every pull request (`.github/workflows/ci.yml`).
