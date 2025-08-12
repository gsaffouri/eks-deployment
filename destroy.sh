#!/usr/bin/env bash
set -euo pipefail
# Usage: ./deploy.sh [-p]    (-p applies; otherwise plan only)

APPLY=0
while getopts ":p" opt; do case $opt in p) APPLY=1 ;; esac; done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read real values from aws-bootstrap **main.tf** (not the resources template)
BOOTSTRAP_TF="$ROOT/../aws-bootstrap/main.tf"
if [[ ! -f "$BOOTSTRAP_TF" ]]; then
  echo "ERROR: $BOOTSTRAP_TF not found. Make sure repos are siblings and bootstrap ran."
  echo "If your folder is named aws-bootstrap-main, change BOOTSTRAP_TF accordingly."
  exit 1
fi

# Require committed backend stub in root module
if [[ ! -f "$ROOT/backend.tf" ]]; then
  echo 'ERROR: backend.tf missing. Commit this minimal file:'
  echo 'terraform { backend "s3" {} }'
  exit 1
fi

# Parse bucket/region/ddb from bootstrap main.tf
parse_val() { sed -nE "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\"?([^\"#]+)\"?.*/\1/p" "$BOOTSTRAP_TF" | head -1; }
BUCKET="$(parse_val bucket)"
REGION="$(parse_val region)"
DYNAMO="$(parse_val dynamodb_table)"

if [[ -z "${BUCKET:-}" || "$BUCKET" == "UPDATE_ME" || -z "${REGION:-}" || -z "${DYNAMO:-}" ]]; then
  echo "ERROR: Could not read bucket/region/dynamodb_table from $BOOTSTRAP_TF"
  exit 1
fi

echo "[eks] backend -> bucket=$BUCKET  region=$REGION  ddb=$DYNAMO"

# Clean init each run so providers resolve cleanly
rm -rf "$ROOT/.terraform" "$ROOT/.terraform.lock.hcl" "$ROOT/tfplan" || true

terraform -chdir="$ROOT" init -reconfigure -upgrade \
  -backend-config="bucket=${BUCKET}" \
  -backend-config="key=eks-deployment/terraform.tfstate" \
  -backend-config="region=${REGION}" \
  -backend-config="dynamodb_table=${DYNAMO}"

terraform -chdir="$ROOT" fmt -recursive
terraform -chdir="$ROOT" validate
terraform -chdir="$ROOT" plan -out=tfplan -input=false

if [[ $APPLY -eq 1 ]]; then
  terraform -chdir="$ROOT" apply -input=false tfplan
  echo "[eks] done."
else
  echo "[eks] plan ready. Re-run with -p to apply."
fi
