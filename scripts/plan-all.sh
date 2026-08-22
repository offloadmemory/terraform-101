#!/usr/bin/env bash
set -euo pipefail
for env in dev staging prod; do
  for comp in network database ecs; do
    dir="environments/${env}/${comp}"
    echo "==> plan ${dir}"
    (cd "${dir}" && terraform init && terraform plan)
  done
done
echo "Plans complete."
