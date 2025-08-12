#!/usr/bin/env bash
set -euo pipefail

# Usage: ./deploy.sh [-p]
#   -p  apply (otherwise plan only)

APPLY=0
while getopts ":p" opt; do
  case $opt in
    p) APPLY=1 ;;
  esac
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Expect bootstrap to have already run and produced main.remote.tf
BOOTSTRAP_TF="${BOOTSTRAP_TF:-$ROOT/../aws-bootstrap/resources/main.remote.tf}"
if [[ ! -f "$BOOTSTRAP_TF" ]]; then
  echo "ERROR: Can't find $BOOTSTRAP_TF"
  echo "Repos must be sibling folders and aws-bootstrap must be deployed first."
  exit 1
fi

# Read backend values from bootstrap output
BUCKET=$(awk -F\" '/bucket *= *"/{print $2;exit}' "$BOOTSTRAP_TF")
REGION=$(awk -F\" '/region *= *"/{print $2;exit}' "$BOOTSTRAP_TF")
DYNAMO=$(awk -F\" '/dynamodb_table *= *"/{print $2;exit}' "$BOOTSTRAP_TF")

if [[ -z "${BUCKET:-}" || "$BUCKET" == "UPDATE_ME" ]]; then
  echo "ERROR: Bootstrap bucket unset. Run aws-bootstrap/deploy.sh -p first."
  exit 1
fi

# Require a committed backend.tf (no one-off file shenanigans)
if [[ ! -f "$ROOT/backend.tf" ]]; then
  echo "ERROR: backend.tf missing. Commit this minimal file:"
  echo 'terraform { backend "s3" {} }'
  exit 1
fi

# Fresh init each run so providers upgrade to what the modules want
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
  echo "[eks-deployment] done."
else
  echo "[eks-deployment] plan ready. Re-run with -p to apply."
fi
