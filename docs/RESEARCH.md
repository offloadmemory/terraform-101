# Terraform Enterprise Folder Structure — Research & Benchmark

**Date:** 2026-08-23
**Repo:** `offloadmemory/terraform-101`
**Question researched:** *What is the right, enterprise-grade Terraform folder structure for managing multi-account infrastructure — and how does this repo measure up?*

---

## 1. The sources (who defines "the standard")

| Source | What it prescribes | Why it matters |
|---|---|---|
| **HashiCorp Style Guide** (developer.hashicorp.com/terraform/language/style, 2026) | File conventions (`main.tf`, `providers.tf`, `terraform.tf`, `backend.tf`, `outputs.tf`, `variables.tf`, `locals.tf`), `./modules/<name>` local-module location, **store infrastructure config separately from module code**, one directory per environment + one state file per directory when not using HCP Terraform, `tfe_outputs`/data sources over raw `terraform_remote_state`, pin versions, commit `.terraform.lock.hcl`, tests + policy | The vendor's current canonical guidance (the "source of truth" for structure) |
| **HashiCorp — Structuring Configuration for Production** (hashicorp.com blog) | `modules/` + separate environment folders (`prod/`, `staging/`), each env folder = own state, selective module import per env, registry for module distribution | The original, still-cited blueprint for env-centric layouts |
| **HashiCorp Recommended Practices / HCP Terraform docs** | Monorepo is fine for enterprise if each workspace targets a directory and modules are registered; separate configurations or shared modules for env differences; workspace = environment | Validates monorepo + per-component workspaces |
| **Gruntwork / Terragrunt — Recommended Folder Structure** | Two repos: `modules` (blueprints) + `live` (houses). Canonical live hierarchy: **account → region → environment → category → resource** (e.g. `prod/us-east-1/prod/networking/vpc/terragrunt.hcl`), with `_global` for region-agnostic resources; one state file per leaf; variable hierarchy (`account.hcl`/`region.hcl`/`env.hcl`) | The de-facto standard for **multi-account at scale**; Terragrunt's Act-2 target for this repo |
| **terraform-best-practices.com** (Anton Babenko) | For large multi-account: `modules/` at root + **one folder per environment** (`prod/`, `stage/`), each env a composition (main/variables/outputs/tfvars), env-versioned module pins; `terraform.tfvars` only at composition level | Concrete worked example of the pure-Terraform large structure — matches this repo's shape |
| **AWS Prescriptive Guidance / Control Tower / AFT** | Multi-account = landing zone: separate accounts per environment/business unit, OU structure, baseline modules (CloudTrail, Config, GuardDuty, Security Hub) applied to **every** account, account factory for vending | Sets the account-level operating model the folder structure serves |
| **Google Cloud Terraform best practices** | Standard module structure (`main.tf`, `variables.tf`, `outputs.tf`, `README.md`, `examples/`), descriptions on every variable/output, group resources by purpose | Reinforces module hygiene |

**Convergence.** Every source agrees on the same skeleton for multi-account, multi-environment Terraform:

```
┌─────────────────────────────────────────────────────────────────────┐
│  modules/            # REUSABLE LAYER — "blueprints", versioned      │
│    <component>/      #   main.tf, variables.tf, outputs.tf, README   │
│                                                                     │
│  <env>/ or <account>/  # LIVE LAYER — "houses", thin roots          │
│    <component>/      #   one directory = one workspace = one state   │
└─────────────────────────────────────────────────────────────────────┘
```

The only genuinely contested decision is **monorepo vs polyrepo** (HashiCorp: either, prefer separate module repos at scale; Gruntwork: separate `modules` and `live` repos). For a workshop repo, monorepo with a clean `modules/` boundary is the pragmatic standard, and this repo already made that choice.

---

## 2. Benchmark: this repo vs the enterprise standard

### 2.1 What already matches (keep — these are correct)

| Enterprise requirement | Status in repo | Detail |
|---|---|---|
| Modules separated from live code | ✅ | `modules/` at root, `environments/*` thin roots — exactly HashiCorp + Babenko |
| One workspace = one dir = one state | ✅ | `environments/{env}/{component}`, per-component state keys |
| Env-per-folder (no `terraform workspace` for envs) | ✅ | HashiCorp: "use a directory for each environment so that each one has a separate state file" |
| Remote state + locking | ✅ | S3 + `use_lockfile` (current standard) |
| No secrets in code | ✅ | managed master password; AWS profiles in tfvars only |
| Version pins | ✅ | `required_version` + provider `~> 5.0`; committed lock files |
| Modules have descriptions on variables | ⚠️ partial | Module variables ✅; **component-level variables lack descriptions** |
| Standard module structure | ⚠️ partial | Missing `README.md` + `examples/` per module (required by standard) |
| File conventions | ⚠️ partial | `provider` blocks live inside `main.tf` (HashiCorp: `providers.tf`); version block in `versions.tf` (HashiCorp: `terraform.tf`) |
| Multi-account account model | ⚠️ | Structure supports it (profile per env); account IDs not first-class (relies on CLI profiles) |
| CI/CD + review gates | ❌ | Only `make validate` locally; no pipeline |
| Linting / policy-as-code | ❌ | No tflint, no checkov/tfsec, no pre-commit |
| Module registry + `version` constraints | ❌ | Local `source = "../../"` — no pins, no promotion control |
| State sharing (cross-component) | ⚠️ | `terraform_remote_state` (HashiCorp now recommends `tfe_outputs`/data sources; Terragrunt `dependency` in Act II) |
| Account baseline (CloudTrail/Config/GuardDuty) | ❌ | Only state buckets; no landing-zone baseline |
| Drift detection | ❌ | None |

### 2.2 Where the layout itself would evolve at fleet scale

| Repo today | Enterprise target (Gruntwork/consensus) | When to adopt |
|---|---|---|
| `environments/dev/{component}` | `accounts/dev/us-east-1/{component}` (add region level) | When multi-region arrives |
| `environments/bootstrap/` | `_global` per account or a dedicated `mgmt/`/org account | When Control Tower/AFT or a mgmt account exists |
| Repo-relative `modules/` | Registry-hosted modules with `version` pins | Before >1 team consumes them |
| `terraform_remote_state` | `tfe_outputs`, data sources, or Terragrunt `dependency` | Before state coupling becomes a prod incident |

The **layout choice is already right** for a pure-Terraform, 3-account demo; the missing enterprise pieces are **file-convention hygiene, module documentation/examples, quality gates (pre-commit, lint, CI), and the account/region axis for later scale** — all of which can be added without breaking Act II (Terragrunt).

---

## 3. Changes applied to this repo (this pass)

Purely additive / structural; **no state keys, module interfaces, or apply order change**, so existing workspaces and the Act II path are unaffected:

1. **`providers.tf`** — moved `provider "aws"` blocks out of `main.tf` into a dedicated file (HashiCorp file convention) in every component root and `bootstrap/`.
2. **`terraform.tf`** — renamed `versions.tf` → `terraform.tf` (current HashiCorp naming for the `required_version`/`required_providers` block).
3. **Variable + output hygiene** — every component-level variable now carries `description` + `type` (HashiCorp style guide; Google AWS module guides); outputs carry `description` and `sensitive` where appropriate (`db_endpoint`, `db_name`, `db_port` in the database module + component outputs).
4. **Module READMEs + `examples/`** — every module now documents itself (`README.md` with usage) and ships an `examples/basic/` runnable composition, per the standard module structure.
5. **`.github/workflows/ci.yml`** — PR CI: `fmt` → `validate` → `tflint` on every component; optional OIDC-backed `plan` job (disabled by default — no creds required to keep the repo green).
6. **`.pre-commit-config.yaml`** — `terraform_fmt`, `terraform_validate`, `terraform_docs`, `tflint` hooks (enterprise gate, opt-in run).
7. **`docs/RESEARCH.md`** — this document.

### Not changed (deliberately — they belong to Act II)

- `backend.tf` static keys (backend interpolation is impossible in pure Terraform; Terragrunt `remote_state` cures it)
- `terraform_remote_state` cross-component coupling (Terragrunt `dependency` cures it)
- Unversioned local modules (private registry is a Phase-3 move)
- No CI apply automation beyond plan (gated apply/approval is an Atlantis/Actions phase)

---

## 4. Sources consulted

- HashiCorp: *Style Guide* — developer.hashicorp.com/terraform/language/style
- HashiCorp: *Structuring HashiCorp Terraform Configuration for Production* — hashicorp.com/blog/structuring-hashicorp-terraform-configuration-for-production
- HashiCorp: *Learn Terraform recommended practices* — developer.hashicorp.com/terraform/cloud-docs/recommended-practices
- HashiCorp: *Manage Terraform configurations* (monorepo/workspace patterns) — developer.hashicorp.com/terraform/cloud-docs/workspaces/configurations
- Gruntwork: *Recommended Folder Structure — Infrastructure Live* — docs.gruntwork.io/2.0/docs/overview/concepts/infrastructure-live (+ `terragrunt-infrastructure-live-example`)
- Anton Babenko: *Terraform Best Practices — Code structure / Large-size infrastructure* — terraform-best-practices.com/code-structure, examples/large-terraform
- AWS Prescriptive Guidance: *Landing zone* + *Control Tower AFT overview* — docs.aws.amazon.com (multi-account account baseline model)
- Google Cloud: *Best practices for general style and structure* — docs.cloud.google.com/docs/terraform/best-practices/general-style-structure
- CloudSpinx / OneUptime / StackHarbor: Terragrunt multi-account layout articles (2026) — corroborating the `account/region/env/category/resource` hierarchy
