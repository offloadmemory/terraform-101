# Demo script — Act 1 (pure Terraform)

## Beat 0 — The shape (2 min)
Walk the tree: `environments/{dev,staging,prod}/{network,database,ecs}`.
Note modules at root, one component = one workspace = one state.

## Beat 1 — Bootstrap chicken-and-egg (2 min)
Run `environments/bootstrap` once. Ask: *why is this its own thing?* Answer:
Terraform can't reference a bucket that doesn't exist yet. Terragrunt
`remote_state` cures this later.

## Beat 2 — network apply (5 min)
Apply `dev/network`. Point at the duplicated `provider` block; every
environment re-types region/profile. **Gap #1, #3.**

## Beat 3 — database reads network (3 min)
Show `data "terraform_remote_state"` in `dev/database/main.tf` — the bucket
key `network/terraform.tfstate` is hardcoded text. Apply it. **Gap #4.**

## Beat 4 — ecs (4 min)
Same remote_state pattern, plus ALB DNS output. Apply. Open the ALB DNS.

## Beat 5 — staging/prod exist but are copies (3 min)
`tree environments` again. Show staging/network and dev/network `main.tf`
are identical; only backend+tfvars differ. Name the cost of that. **Gap #2, #5.**

## Beat 6 — recap (2 min)
Six gaps on the board (docs/GAPS.md). Preview: Terragrunt collapses each.
