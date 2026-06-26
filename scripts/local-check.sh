#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGETS=(
  "environments/sandbox/1-networking"
  "environments/sandbox/2-cluster"
)

for target in "${TARGETS[@]}"; do
  echo "==> Checking ${target}"
  (
    cd "${ROOT_DIR}/${target}"
    terraform fmt -check -recursive
    terraform init -backend=false -input=false
    terraform validate
  )
done
