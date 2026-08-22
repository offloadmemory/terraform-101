# Terraform Multi-Account / Multi-Environment Demonstration

A live, pure-Terraform multi-account infrastructure demo: three AWS accounts
(dev, staging, prod), each with a VPC network, an RDS PostgreSQL database, and
an ECS Fargate service behind an ALB. The repo's layout and deliberate
repetition illustrate Terraform's multi-account pain points — the setup for a
follow-on Terragrunt act.

## Layout

    modules/          hand-rolled modules shared across environments
    environments/     one workspace per environment & component (own state)
      bootstrap/      creates the per-account state buckets (apply once)
      dev/            network · database · ecs
      staging/        network · database · ecs
      prod/           network · database · ecs

## Prereqs & setup

See `docs/SETUP.md` (AWS CLI profiles, costs, teardown).

## Apply order (per environment)

    bootstrap → network → database → ecs

Live demo applies `dev` only; `staging` and `prod` are coded and validated.
See `docs/DEMO-SCRIPT.md` for the narration, `docs/GAPS.md` for the gap table.

## Commands

    make fmt        # terraform fmt --recursive
    make validate   # init -backend=false + validate on every component
    make plan       # init + plan on every component (needs creds)
    make destroy    # teardown every component, reverse order (needs creds)
