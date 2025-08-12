#!/usr/bin/env bash
set -euo pipefail
# Usage: ./deploy.sh [-p]   (-p applies; otherwise plan only)

APPLY=0
while getopts ":p" opt; do case $opt in p) APPLY=1 ;; esac; done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Require backend stub
[[ -f "$ROOT/backend.tf" ]] || { echo 'ERROR: backend.tf missing (terraform { backend "s3" {} })'; exit 1; }

# Find bootstrap repo next door
BOOTSTRAP_DIR=""
for d in "$ROOT/../aws-bootstrap" "$ROOT/../aws-bootstrap-main"; do
  [[ -d "$d" ]] && BOOTSTRAP_DIR="$d" && break
done
[[ -n "$BOOTSTRAP_DIR" ]] || { echo "ERROR: Could not find a sibling aws-bootstrap repo."; exit 1; }

echo "[eks] reading backend from bootstrap state…"
terraform -chdir="$BOOTSTRAP_DIR" init -reconfigure -input=false >/dev/null

# Module-safe scanning
S3_ADDR="$(terraform -chdir="$BOOTSTRAP_DIR" state list | grep -m1 'aws_s3_bucket\.' || true)"
DDB_ADDR="$(terraform -chdir="$BOOTSTRAP_DIR" state list | g
