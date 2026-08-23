# Terraform Multi-Account / Multi-Environment Demonstration — Design Spec

**Date:** 2026-08-22
**Status:** Approved (Part 1 scope)
**Path:** Architectural

> **Amendment (2026-08-23):** state locking migrated to **S3-native
> `use_lockfile`** (Terraform ≥ 1.11, GA since 1.11). The DynamoDB lock table
> is removed from `modules/state` and all backends — locking now uses a
> `<key>.tflock` object in the state bucket via S3 conditional writes. §2,
> §4.1 and §6 are updated to match; the plan doc is left as the historical
> record.

## 1. Purpose & Narrative

A live demonstration of operating Terraform across **multiple AWS accounts** and
**multiple environments**, told in two acts:

- **Act 1 — Pure Terraform (this spec):** a working multi-account,
  multi-environment setup that succeeds, while deliberately surfacing the
  friction Terraform has in this scenario: repeated boilerplate, static
  backend config, no shared configuration, no cross-component/cross-env
  orchestration, and a state-bootstrap chicken-and-egg.
- **Act 2 — Terragrunt (deferred):** re-express the same infrastructure with
  `terragrunt.hcl` so the mirror reveals how each Act 1 gap is addressed.
  Act 2 is **out of scope** for this spec; an integration path appendix keeps
  the current layout compatible.

**Audience:** infra/DevOps engineers; the demo is presented live, applying real
infrastructure in the `dev` environment while `staging`/`prod` are coded but
not applied.

## 2. Decisions Locked

| Decision | Choice |
|---|---|
| Accounts | 3 AWS accounts: dev, staging, prod (one env = one account) |
| Credentials | Named AWS CLI profiles `dev` / `staging` / `prod`; not yet provisioned — structure + docs designed for it; a single account can stand in initially |
| App compute | ECS Fargate + ALB, placeholder container (`nginx:alpine`), no real app |
| Database | AWS RDS PostgreSQL |
| Modules | Hand-rolled local modules, shared by both acts |
| Apply scope | All 3 envs coded; **dev** applied live |
| Directory structure | Environment-centric (`environments/{env}/{component}/`) with a 1:1 Terragrunt mirror planned |
| Terraform tooling | Terraform 1.11+, AWS provider 5.x, HCL only |
| State locking | S3-native `use_lockfile` (Terraform ≥ 1.11); no DynamoDB |

## 3. Repository Layout

```
terraform-101/
├── README.md                       # demo guide, prerequisites, quickstart
├── docs/
│   ├── SETUP.md                     # profiles, prereqs, cost & teardown notes
│   ├── DEMO-SCRIPT.md               # act-by-act live walkthrough (narration beats)
│   └── GAPS.md                      # "Terraform pain → cure" table (Act 2 preview)
├── modules/                         # hand-rolled, shared by BOTH acts
│   ├── state/                       #   S3 backend bucket (S3-native lockfile)
│   ├── network/                     #   VPC, subnets, IGW, NAT, route tables, SGs
│   ├── database/                    #   RDS PostgreSQL + subnet group + SG
│   └── ecs/                         #   ECS cluster, Fargate svc, task def, ALB
├── environments/                    # ══ ACT 1: PURE TERRAFORM ══
│   ├── bootstrap/                   #   creates state buckets for all 3 accounts
│   ├── dev/
│   │   ├── network/                 #     main.tf · backend.tf · variables.tf · terraform.tfvars
│   │   ├── database/
│   │   └── ecs/
│   ├── staging/                     #   same shape as dev
│   └── prod/                        #   same shape as dev
└── scripts/ + Makefile              # fmt/validate/plan helpers
```

`modules/` lives at repo root (not under `environments/`) so Act 2 reuses it.

## 4. Modules (Hand-rolled)

### 4.1 `modules/state`
Bootstrap-only module. Creates per-account state backend infrastructure.

- **Resources:** `aws_s3_bucket` (versioned, SSE-S3, block-public-access, bucket
  policy disallowing http), `aws_s3_bucket_versioning`. State locking is
  S3-native (`use_lockfile = true` in every backend) — no DynamoDB table.
- **Inputs:** `bucket_name`, `region`, `tags`.
- **Outputs:** `bucket_name`.

### 4.2 `modules/network`
The environment network foundation.
- **Resources:** `aws_vpc`, 3× `aws_subnet` public (`/24`) + 3× `aws_subnet`
  private (`/24`), `aws_internet_gateway`, `aws_nat_gateway`
  (count = `nat_gateway_count`) + `aws_eip` each, public route table → IGW,
  private route table → NAT (per AZ), `aws_security_group` × 3:
  - `alb_sg`: ingress 80/443 from `0.0.0.0/0`, egress all.
  - `ecs_sg`: ingress 80 from `alb_sg`, egress all.
  - `db_sg`: ingress 5432 from `ecs_sg`, egress all.
- **Inputs:** `env_name`, `region`, `vpc_cidr`, `azs`, `public_cidrs`,
  `private_cidrs`, `nat_gateway_count` (1 for demo — cost), `tags`.
- **Outputs:** `vpc_id`, `vpc_cidr_block`, `public_subnet_ids`,
  `private_subnet_ids`, `alb_sg_id`, `ecs_sg_id`, `db_sg_id`.

### 4.3 `modules/database`
RDS PostgreSQL.
- **Resources:** `aws_db_subnet_group` (private subnets),
  `aws_db_instance` with `engine = postgres`, `engine_version = 16`,
  `manage_master_password = true` (RDS-managed, no secrets in code),
  `storage_encrypted = true`, `storage_type = gp3`, `backup_retention_period`
  (1 dev / 7 prod), `multi_az` (false dev / true prod),
  `deletion_protection` (false dev / true prod), `skip_final_snapshot` (true
  dev / false prod), `vpc_security_group_ids = [db_sg]`, `publicly_accessible = false`.
- **Inputs:** `env`, `db_name`, `instance_class`, `allocated_storage`,
  `multi_az`, `deletion_protection`, `subnet_ids`, `db_sg_id`, `tags`.
- **Outputs:** `db_endpoint`, `db_name`, `db_port`, `db_sg_id`.

### 4.4 `modules/ecs`
Application serving layer.
- **Resources:**
  - `aws_ecs_cluster` (Fargate; cluster management cost ≈ $0).
  - `aws_cloudwatch_log_group` for task logs.
  - `aws_ecs_task_definition`: `nginx:alpine` container, 256 cpu / 512 mem,
    `network_mode = awsvpc`, `logConfiguration` → CW, execution role.
  - `aws_ecs_service` in private subnets, `ecs_sg`, `desired_count` (1 dev).
  - `aws_alb` (internet-facing) in public subnets + `alb_sg`;
    `aws_alb_target_group` (health check `/`, nginx returns 200);
    `aws_alb_listener` (80 → TG) + listener rule.
  - `aws_iam_role` task execution (`AmazonECSTaskExecutionRolePolicy`) and
    `aws_iam_role` task role.
- **Outputs:** `cluster_name`, `service_name`, `alb_dns_name`,
  `task_definition_arn`.

## 5. Environment Layout — Act 1

Each `environments/{env}/{component}/` holds exactly four files:

| File | Purpose |
|---|---|
| `main.tf` | `provider "aws"` block (profile, region) + module call |
| `backend.tf` | static `terraform { backend "s3" { bucket = "tfstate-<env>", key = "<env>/<component>/terraform.tfstate", ... } }` — values hand-written, never derived |
| `variables.tf` | thin pass-through of module inputs |
| `terraform.tfvars` | the actual per-environment values |

Cross-component data uses `data "terraform_remote_state"`:
- `database` reads network subnet ids + db_sg; `ecs` reads network subnet ids
  + alb_sg/ecs_sg. Backend keys are hardcoded strings in the data source —
  a deliberate brittleness to demonstrate.

## 6. State & Apply Order

1. `environments/bootstrap/` — one apply, all three accounts: builds
   `tfstate-dev|staging|prod` buckets via `modules/state`
   with three provider aliases (locking is S3-native, so no lock table).
2. Per environment, apply in dependency order: `network` → `database` → `ecs`.
3. Nothing can run before bootstrap — the chicken-and-egg to name on stage.

## 7. The Deliberate Gaps (the point of the demo)

1. **Boilerplate repetition** — 12 env/component folders of near-identical
   provider + backend blocks.
2. **Static backend config** — bucket/key can’t interpolate; hand-edited.
3. **No single source of truth** — region, account, common tags repeated.
4. **Cross-component coupling** — `terraform_remote_state` with hardcoded
   keys; brittle and ordering-sensitive.
5. **No orchestration** — sequential manual applies; no promotion story
   dev→staging→prod.
6. **Bootstrap chicken-and-egg** — backend must exist before `terraform init`.

Each is paired with a “cure” note in `docs/GAPS.md` (Terragrunt `include`,
`remote_state`, `generate`, `dependency`, `run-all`) without implementing it.

## 8. Credentials, Cost, Validation

- **Profiles:** `dev`/`staging`/`prod` in `~/.aws/credentials`; `profile`
  variable defaults per folder; one account may back all three initially.
  Documented in `docs/SETUP.md`.
- **Cost floor (dev running):** NAT+EIP ≈ $34, RDS micro ≈ $13, ALB ≈ $16,
  Fargate ≈ $5 → ≈ $70/mo. Teardown via per-component `terraform destroy`;
  `docs/SETUP.md` carries the breakdown and a “destroy after demo” callout.
- **prod contrasts:** `multi_az = true`, `deletion_protection = true`,
  `skip_final_snapshot = false`, backup 7d, larger instance class.
- **Validation:** `terraform fmt -recursive`; `terraform validate` per
  component; `terraform plan` per component. Makefile targets
  (`fmt`, `validate`, `plan`); `scripts/` for loop helpers.

## 9. Deliverables

1. `modules/{state,network,database,ecs}/` — valid, fmt-clean modules.
2. `environments/{bootstrap,dev,staging,prod}/...` — all 12 components coded.
3. `docs/` — `SETUP.md`, `DEMO-SCRIPT.md` (act-by-act narration), `GAPS.md`.
4. `README.md`, `Makefile`, `scripts/`.
5. Verified: fmt + validate + plan green for all folders against an
   unprovisioned profile where possible.

## 10. Out of Scope / Deferred

- **Act 2 — Terragrunt** (`terragrunt-live/`): layout reserved in §3 (the
  mirror); no code written until requested. Integration path: root `modules/`
  reuse is unchanged; env folder names identical.
- Cross-account IAM roles/assume-role chaining (profiles suffice for demo).
- AWS Organizations / Control Tower / landing-zone scaffolding.
- ECR image registry + app source (placeholder `nginx` image only).
