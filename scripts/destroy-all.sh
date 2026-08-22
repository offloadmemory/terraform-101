#!/usr/bin/env bash
set -euo pipefail
for env in dev staging prod; do
  for comp in ecs database network; do
    dir="environments/${env}/${comp}"
    echo "==> destroy ${dir}"
    (cd "${dir}" && terraform init && terraform destroy -auto-approve)
  done
done
echo "Teardown complete."
