# Terraform Multi-Account / Multi-Environment Demonstration

A live, pure-Terraform multi-account infrastructure demo: three AWS accounts
(dev, staging, prod), each with a VPC network, an RDS PostgreSQL database, and
an ECS Fargate service behind an ALB. The repo's layout and deliberate
repetition illustrate Terraform's multi-account pain points — the setup for a
follow-on Terragrunt act. The layout follows the **enterprise folder
structure standard** (HashiCorp style guide / Gruntwork reference): reusable
modules at the root, one thin root per environment & component, one state per
workspace. See `docs/RESEARCH.md` for the benchmark against the standard.

## Layout

    modules/          hand-rolled modules shared across environments
                      (each: main.tf, providers.tf, variables.tf,
                       outputs.tf, terraform.tf, README.md, examples/)
    environments/     one workspace per environment & component (own state)
      bootstrap/      creates the per-account state buckets (apply once)
      dev/            network · database · ecs
      staging/        network · database · ecs
      prod/           network · database · ecs
    .github/          PR CI (fmt, validate, tflint)
    .pre-commit-config.yaml   local quality gates (fmt/validate/docs/tflint)
```

Each component root follows the HashiCorp file conventions:
`providers.tf` (provider blocks), `main.tf` (module call + data sources),
`variables.tf` / `outputs.tf` (with descriptions; sensitive DB outputs),
`backend.tf` (S3 state pointer), `terraform.tf` (version + provider pins).

## Prereqs & setup

See `docs/SETUP.md` (AWS CLI profiles, costs, teardown) and
`docs/ARCHITECTURE.md` (how the repository, state, and environments are organised).

## Apply order (per environment)

```
bootstrap → network → database → ecs
```

Live demo applies `dev` only; `staging` and `prod` are coded and validated.
See `docs/DEMO-SCRIPT.md` for the narration, `docs/GAPS.md` for the gap table,
`docs/ENVIRONMENT-STRATEGY.md` for why environments are directories rather than
Terraform workspaces, and `docs/CRITIQUE.md` / `docs/RESEARCH.md` for
enterprise-scale benchmarks.

## Commands

    make fmt        # terraform fmt --recursive
    make validate   # init -backend=false + validate on every component
    make plan       # init + plan on every component (needs creds)
    make destroy    # teardown every component, reverse order (needs creds)

Quality gates (enterprise):

    pre-commit run --all-files   # fmt + validate + module docs + tflint
    pre-commit install           # run automatically on git commit

