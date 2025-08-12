#!/usr/bin/env bash
set -euo pipefail
# Usage: ./deploy.sh [-p]   (-p applies; otherwise plan only)

APPLY=0
while getopts ":p" opt; do case "$opt" in p) APPLY=1 ;; *) ;; esac; done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Require backend stub so terraform can accept -backend-config flags
[[ -f "$ROOT/backend.tf" ]] || { echo 'ERROR: backend.tf missing (terraform { backend "s3" {} })'; exit 1; }

# Find bootstrap repo next door
BOOTSTRAP_DIR=""
for d in "$ROOT/../aws-bootstrap" "$ROOT/../aws-bootstrap-main"; do
  [[ -d "$d" ]] && BOOTSTRAP_DIR="$d" && break
done
[[ -n "$BOOTSTRAP_DIR" ]] || { echo "ERROR: Could not find a sibling aws-bootstrap repo."; exit 1; }

echo "[eks] reading backend from bootstrap state…"
terraform -chdir="$BOOTSTRAP_DIR" init -reconfigure -input=false >/dev/null

# --- helpers ---
tf_out_raw() {
  terraform -chdir="$BOOTSTRAP_DIR" output -raw "$1" 2>/dev/null || true
}
first_addr() {
  # pick the first matching address from state list
  terraform -chdir="$BOOTSTRAP_DIR" state list | grep -m1 -E "$1" || true
}
show_attr() {
  local addr="$1" key="$2"
  terraform -chdir="$BOOTSTRAP_DIR" state show "$addr" 2>/dev/null \
    | awk -v k="^\\s*${key}\\s*=" ' $0 ~ k { sub(/.*=\s*"/,""); sub(/".*/,""); print; exit }' \
    || true
}

# Prefer explicit outputs if your bootstrap exports them
BOOTSTRAP_BUCKET="$(tf_out_raw bootstrap_bucket)"
BOOTSTRAP_TABLE="$(tf_out_raw bootstrap_dynamodb_table)"
BOOTSTRAP_REGION="$(tf_out_raw bootstrap_region)"

# Fallback to scanning state if outputs aren't defined
if [[ -z "${BOOTSTRAP_BUCKET}" ]]; then
  S3_ADDR="$(first_addr '(^|\\.)aws_s3_bucket(\\.|$)')"
  [[ -n "$S3_ADDR" ]] || { echo "ERROR: Could not find aws_s3_bucket in bootstrap state."; exit 1; }
  BOOTSTRAP_BUCKET="$(show_attr "$S3_ADDR" bucket)"
fi

if [[ -z "${BOOTSTRAP_TABLE}" ]]; then
  DDB_ADDR="$(first_addr '(^|\\.)aws_dynamodb_table(\\.|$)')"
  [[ -n "$DDB_ADDR" ]] || { echo "ERROR: Could not find aws_dynamodb_table in bootstrap state."; exit 1; }
  BOOTSTRAP_TABLE="$(show_attr "$DDB_ADDR" name)"
fi

# Region: output > env > sane default
if [[ -z "${BOOTSTRAP_REGION}" ]]; then
  BOOTSTRAP_REGION="${AWS_REGION:-us-east-1}"
fi

[[ -n "${BOOTSTRAP_BUCKET}" && -n "${BOOTSTRAP_TABLE}" && -n "${BOOTSTRAP_REGION}" ]] || {
  echo "ERROR: failed to resolve bucket/table/region from bootstrap." >&2
  exit 1
}

export AWS_REGION="$BOOTSTRAP_REGION"

echo "[eks] initializing terraform backend…"
terraform -chdir="$ROOT" init -reconfigure \
  -backend-config="bucket=${BOOTSTRAP_BUCKET}" \
  -backend-config="key=eks-deployment/terraform.tfstate" \
  -backend-config="region=${BOOTSTRAP_REGION}" \
  -backend-config="dynamodb_table=${BOOTSTRAP_TABLE}"

if (( APPLY == 1 )); then
  echo "[eks] terraform plan -out=tfplan (safety)…"
  terraform -chdir="$ROOT" plan -out=tfplan
  echo "[eks] terraform apply…"
  terraform -chdir="$ROOT" apply -auto-approve tfplan
else
  echo "[eks] terraform plan…"
  terraform -chdir="$ROOT" plan -out=tfplan
  echo "[eks] plan saved to tfplan (run with -p to apply)"
fi

echo "[eks] done."
