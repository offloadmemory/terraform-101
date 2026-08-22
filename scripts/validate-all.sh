#!/usr/bin/env bash
set -euo pipefail
for env in dev staging prod; do
  for comp in network database ecs; do
    dir="environments/${env}/${comp}"
    echo "==> validate ${dir}"
    (cd "${dir}" && terraform fmt --recursive && terraform init -backend=false && terraform validate)
  done
done
echo "All components validated."
