#!/usr/bin/env bash
set -euo pipefail
# Usage: ./deploy.sh [-p]    # default: plan only, -p: apply

APPLY=0
while getopts ":p" opt; do case "$opt" in p) APPLY=1 ;; esac; done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-$ROOT/../aws-bootstrap}"
STATE_KEY="${EKS_STATE_KEY:-eks-deployment/terraform.tfstate}"

[[ -f "$ROOT/backend.tf" ]] || { echo 'ERROR: backend.tf missing (terraform { backend "s3" {} })'; exit 1; }
[[ -d "$BOOTSTRAP_DIR" ]] || { echo "ERROR: bootstrap repo not found at $BOOTSTRAP_DIR"; exit 1; }

echo "[eks] reading backend from bootstrap state…"
terraform -chdir="$BOOTSTRAP_DIR" init -reconfigure -input=false >/dev/null

BUCKET=$(terraform -chdir="$BOOTSTRAP_DIR" output -raw bootstrap_bucket)
TABLE=$(terraform -chdir="$BOOTSTRAP_DIR" output -raw bootstrap_dynamodb_table)
REGION=$(terraform -chdir="$BOOTSTRAP_DIR" output -raw bootstrap_region)

[[ -n "${BUCKET:-}" && -n "${TABLE:-}" && -n "${REGION:-}" ]] || {
  echo "ERROR: missing outputs in aws-bootstrap (need bootstrap_bucket, bootstrap_dynamodb_table, bootstrap_region)"; exit 1;
}

export AWS_REGION="$REGION"

echo "[eks] initializing terraform backend…"
terraform -chdir="$ROOT" init -reconfigure \
  -backend-config="bucket=${BUCKET}" \
  -backend-config="key=${STATE_KEY}" \
  -backend-config="region=${REGION}" \
  -backend-config="dynamodb_table=${TABLE}"

if (( APPLY == 1 )); then
  echo "[eks] plan → apply"
  terraform -chdir="$ROOT" plan -out=tfplan
  terraform -chdir="$ROOT" apply -auto-approve tfplan
else
  echo "[eks] plan only (use -p to apply)"
  terraform -chdir="$ROOT" plan -out=tfplan
fi

echo "[eks] done."
