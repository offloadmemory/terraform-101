# Terraform pain points on display — and where Terragrunt cures them

| # | Gap demonstrated in Part 1 | Where it shows | Terragrunt cure (Act 2 preview) |
|---|---|---|---|
| 1 | Boilerplate repetition: provider + module call copied into 12 component roots | every `main.tf` | `include "root.hcl"` + `generate` |
| 2 | Static backend: bucket/key hardcoded, can't derive env | every `backend.tf` | `remote_state` block builds the key from the path |
| 3 | No single source of truth for region/profile/common tags | every `terraform.tfvars` | `env.hcl`/`account.hcl` inherited via `include` |
| 4 | Cross-component coupling via hardcoded remote-state keys | `data "terraform_remote_state"` in db/ecs | `dependency` blocks with typed outputs |
| 5 | No orchestration: sequential manual applies, no promotion story | the apply sequence | `run-all apply` + `dependencies` |
| 6 | Bootstrap chicken-and-egg: state infra before state | `environments/bootstrap` | `remote_state` auto-creates bucket + lock |
