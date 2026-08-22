#!/usr/bin/env bash
# Teardown in reverse apply order (ecs -> database -> network) for all envs.
# Note: prod/database is deletion-protected by design; if prod was ever
# applied, its destroy will fail and set -e will stop the loop here.
set -euo pipefail
for env in dev staging prod; do
  for comp in ecs database network; do
    dir="environments/${env}/${comp}"
    echo "==> destroy ${dir}"
    (cd "${dir}" && terraform init && terraform destroy -auto-approve)
  done
done
echo "Teardown complete."
