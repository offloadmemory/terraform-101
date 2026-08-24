# Runbook — Apply the Full Stack Locally, From Scratch

**Date:** 2026-08-24
**Repo:** `offloadmemory/terraform-101`
**Goal:** Take a clean machine, authenticate to AWS, and apply the entire demo
stack (VPC network, RDS PostgreSQL, ECS Fargate behind an ALB) **for the `dev`
environment**, step by step, copy-paste style.

**What you will end up with (all in region `ap-south-1`):**

- 3 S3 buckets holding Terraform state: `tfstate-{dev,staging,prod}-kartik-2026`
- A VPC (`10.0.0.0/16`) with 3 public + 3 private subnets, IGW, NAT gateway + EIP
- An RDS PostgreSQL 16.15 instance (`dev-postgres`)
- An ECS Fargate service running `nginx:alpine` behind an Application Load Balancer

> Apply order matters: **bootstrap → network → database → ecs**.
> `database` and `ecs` both read the `network` state via
> `data "terraform_remote_state"`, so the network must exist first.

---

## Step 0 — Prerequisites

Install tools and clone the repo. Verify the versions:

```bash
terraform -version        # needs >= 1.11 (verified with 1.13.4)
aws --version             # needs AWS CLI v2
git --version
```

Clone and enter the repo:

```bash
git clone git@github.com:offloadmemory/terraform-101.git
cd terraform-101
```

---

## Step 1 — Set up AWS named profiles

The repo uses three named profiles — `dev`, `staging`, `prod` — each pointed at
its own `backend.tf` bucket. For the live demo all three may point at the same
AWS account; the code is structured for separate accounts regardless.

Edit `~/.aws/credentials` and add:

```ini
[dev]
aws_access_key_id = AKIA...
aws_secret_access_key = ...

[staging]
aws_access_key_id = AKIA...
aws_secret_access_key = ...

[prod]
aws_access_key_id = AKIA...
aws_secret_access_key = ...
```

Then set the region for every profile in `~/.aws/config` (the code also carries
`ap-south-1` explicitly in each provider block, so this is belt-and-braces):

```ini
[profile dev]
region = ap-south-1
output = json

[profile staging]
region = ap-south-1
output = json

[profile prod]
region = ap-south-1
output = json
```

**Verify the credentials actually work** — you should see your account ID:

```bash
aws sts get-caller-identity --profile dev
```

Expected output shape:

```json
{
  "UserId": "AIDA...",
  "Account": "686346930071",
  "Arn": "arn:aws:iam::686346930071:user/kartikmanimuthu@gmail.com"
}
```

> **Region check:** everything in this demo must be in **`ap-south-1`**, not
> `us-east-1`. If you accidentally created resources in the wrong region, destroy
> them and start over.

---

## Step 2 — Know the layout and the apply order

```
environments/
├── bootstrap/     # creates the state buckets — LOCAL state, apply once
├── dev/           # network → database → ecs
├── staging/       # coded + validated, not applied in this demo
└── prod/          # coded + validated, not applied in this demo
modules/           # reusable modules (state, network, database, ecs)
```

Order of commands per component:

```bash
terraform init                 # configure the S3 backend, download providers
terraform plan                 # review the diff (optional but recommended)
terraform apply -auto-approve   # apply without prompts
```

Each component's `backend.tf` already embeds its bucket, region, and profile,
so a plain `terraform init` is all you need — no `-backend-config` flags.

---

## Step 3 — Bootstrap the state buckets (apply once)

This is the only step with **local** state. It creates the three S3 buckets the
other components will store their state in.

```bash
cd environments/bootstrap
terraform init
terraform plan
terraform apply -auto-approve
```

Verify the buckets exist:

```bash
aws s3 ls --profile dev | grep tfstate
```

You should see `tfstate-dev-kartik-2026`, `tfstate-staging-kartik-2026`, and
`tfstate-prod-kartik-2026`.

> **If bootstrap fails with `BucketAlreadyExists`:** S3 bucket names are
> globally unique. Rename them in `environments/bootstrap/main.tf` **and** in
> the matching `backend.tf` files under `environments/{dev,staging,prod}/*/`.
> If a name was only *just* deleted, you may hit `OperationAborted` — wait ~1
> minute and retry, or pick a fresh unique suffix.

---

## Step 4 — Apply the dev network

```bash
cd ../dev/network
terraform init
terraform plan
terraform apply -auto-approve
```

This creates the VPC, subnets, IGW, NAT gateway, route tables, and security
groups. The VPC ID and subnet IDs are written to state as outputs that
`database` and `ecs` will read next.

---

## Step 5 — Apply the dev database

```bash
cd ../database
terraform init
terraform plan
terraform apply -auto-approve
```

This provisions RDS PostgreSQL 16.15 (`dev-postgres`), encrypted with a managed
master password (the secret is generated and held by AWS — nothing to paste in).
Creation takes **~10–15 minutes** while the instance initialises; Terraform will
appear to hang on `Still creating...` — that is normal.

```bash
cd ..
```

---

## Step 6 — Apply the dev ECS service

```bash
cd ../ecs
terraform init
terraform plan
terraform apply -auto-approve
```

This creates the ECS cluster, Fargate task running `nginx:alpine`, and the
Application Load Balancer. It reads the network state (subnets + security
groups) to wire itself into the VPC.

```bash
cd ../..     # back to repo root
```

---

## Step 7 — Verify the live stack end to end

**7a. The ALB should answer HTTP 200** — grab its DNS and curl it:

```bash
cd environments/dev/ecs
curl -I http://$(terraform output -raw alb_dns_name)
```

Expected: `HTTP/1.1 200 OK` with `nginx` headers. (Give it a minute after apply —
the first task boot + health check can take 30–60s.)

**7b. The ECS task should be running:**

```bash
aws ecs list-tasks --cluster dev-ecs-cluster --profile dev
```

**7c. The RDS instance should be `available`:**

```bash
aws rds describe-db-instances --profile dev \
  --query 'DBInstances[0].{Endpoint:Endpoint.Address,Status:DBInstanceStatus}'
```

**7d. Remote state should be in S3** (not on your laptop):

```bash
cd ../..   # repo root
aws s3 ls s3://tfstate-dev-kartik-2026 --recursive --profile dev
```

You should see `network/terraform.tfstate`, `database/terraform.tfstate`, and
`ecs/terraform.tfstate` (plus matching `.tflock` files while a run is active).

---

## Step 8 — (Optional) staging and prod

`staging` and `prod` are fully coded and pass `terraform validate` but are not
applied in the live demo. To apply them, repeat Steps 4–6 in the matching
directory (`cd ../staging/network` …) — same order, same commands.

> **Note:** `prod/database` sets `deletion_protection = true` by design. If you
> ever apply and then destroy prod, the destroy will stop at the database —
> remove `deletion_protection = true` from
> `environments/prod/database/terraform.tfvars` and re-run.

---

## Step 9 — Teardown (reverse order)

Always destroy **ecs → database → network**, then optionally the bootstrap
buckets. The database is the slowest to remove (~15 min); the rest is quick.

```bash
cd environments/dev/ecs       && terraform destroy -auto-approve
cd ../database                && terraform destroy -auto-approve
cd ../network                 && terraform destroy -auto-approve
```

To remove the state buckets too (this is a demo, so they only hold state):

```bash
cd ../../bootstrap && terraform destroy -auto-approve
```

> **Tip:** the repo also ships `scripts/destroy-all.sh`, `scripts/plan-all.sh`,
> and `scripts/validate-all.sh` that loop over every environment × component.

---

## Troubleshooting quick-facts

| Symptom | Cause / fix |
|---|---|
| `BucketAlreadyExists` / `BucketAlreadyOwnedByYou` | S3 bucket name is taken globally. Rename in `bootstrap/main.tf` **and** all matching `backend.tf` files, then `terraform init -reconfigure`. |
| `OperationAborted: A conflicting conditional operation...` | The bucket was just deleted and S3 is still propagating the deletion. Wait ~1 min and retry, or use a fresh unique name. |
| `Error: backend config changed` after renaming a bucket | The old backend no longer exists. Run `terraform init -reconfigure` (there is no old state to migrate). |
| `Cannot find version "16.4"` for postgres | That minor is not offered in `ap-south-1`; the repo pins `16.15` — keep it. |
| Wrong region / resources in `us-east-1` | Destroy them and recreate everything in `ap-south-1` — every provider and backend must match. |
| `terraform destroy` stops at prod/database | `deletion_protection = true` — remove the flag and re-run. |
| `curl` to the ALB hangs or 502s | The Fargate task is still booting or unhealthy. Wait 30–60s; check `aws ecs describe-services --cluster dev-ecs-cluster --services dev-ecs --profile dev` for `runningCount`. |
| `terraform init` fails on S3 access | The profile lacks permissions. Minimum: `s3:GetObject`/`s3:PutObject`/`s3:ListBucket` on the state bucket and `*.tflock` keys (S3-native locking needs no DynamoDB). |

---

## What was created — cost note

While running, the dev stack costs roughly **~$70/month** (NAT+EIP ≈ $34, RDS
micro ≈ $13, ALB ≈ $16, Fargate ≈ $5). **Destroy it after the demo** (Step 9).
