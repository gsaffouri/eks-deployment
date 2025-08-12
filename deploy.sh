#!/usr/bin/env bash
set -euo pipefail
# Usage: ./deploy.sh [-p]   (-p applies; otherwise plan only)

APPLY=0
while getopts ":p" opt; do case $opt in p) APPLY=1 ;; esac; done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Require backend stub
[[ -f "$ROOT/backend.tf" ]] || { echo 'ERROR: backend.tf missing (terraform { backend "s3" {} })'; exit 1; }

# Locate bootstrap repo next door
BOOTSTRAP_DIR=""
for d in "$ROOT/../aws-bootstrap" "$ROOT/../aws-bootstrap-main"; do
  [[ -d "$d" ]] && BOOTSTRAP_DIR="$d" && break
done
[[ -n "$BOOTSTRAP_DIR" ]] || { echo "ERROR: Could not find a sibling aws-bootstrap repo."; exit 1; }

echo "[eks] reading backend from bootstrap state…"
terraform -chdir="$BOOTSTRAP_DIR" init -reconfigure -input=false >/dev/null

S3_ADDR="$(terraform -chdir="$BOOTSTRAP_DIR" state list | grep '^aws_s3_bucket\.' | head -1 || true)"
DDB_ADDR="$(terraform -chdir="$BOOTSTRAP_DIR" state list | grep '^aws_dynamodb_table\.' | head -1 || true)"
[[ -n "$S3_ADDR" && -n "$DDB_ADDR" ]] || { echo "ERROR: bootstrap state missing S3/Dynamo resources."; exit 1; }

BUCKET="$(terraform -chdir="$BOOTSTRAP_DIR" state show "$S3_ADDR" | awk -F ' = ' '/^bucket = /{print $2; exit}' | tr -d '"')"
DYNAMO="$(terraform -chdir="$BOOTSTRAP_DIR" state show "$DDB_ADDR" | awk -F ' = ' '/^name = /{print $2;   exit}' | tr -d '"')"
REGION="$(terraform -chdir="$BOOTSTRAP_DIR" state show "$DDB_ADDR" | awk -F ' = ' '/^arn = /{print $2;    exit}' | sed -E 's/^"arn:aws:dynamodb:([^:]+):.*/\1/' | tr -d '"')"

[[ -n "$BUCKET" && -n "$DYNAMO" && -n "$REGION" ]] || { echo "ERROR: failed to read bucket/table/region from bootstrap state."; exit 1; }

# 👇 Detect deployer's public IP and pass it to Terraform as a var
MYIP="$(curl -fsS https://checkip.amazonaws.com || curl -fsS https://ifconfig.me || true)"
if [[ -z "${MYIP}" ]]; then
  echo "WARNING: could not detect public IP; defaulting endpoint CIDR to 0.0.0.0/0"
  export TF_VAR_endpoint_cidrs='["0.0.0.0/0"]'
else
  export TF_VAR_endpoint_cidrs='["'"${MYIP}"'/32"]'
fi
echo "[eks] allowing endpoint from: ${TF_VAR_endpoint_cidrs}"

# Clean init, then plan/apply
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
