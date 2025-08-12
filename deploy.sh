#!/usr/bin/env bash
set -euo pipefail
# Usage: ./deploy.sh [-p]    (-p applies; otherwise plan only)

APPLY=0
while getopts ":p" opt; do case $opt in p) APPLY=1 ;; esac; done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Require backend stub committed in repo root
if [[ ! -f "$ROOT/backend.tf" ]]; then
  echo 'ERROR: backend.tf missing (needs: terraform { backend "s3" {} })'
  exit 1
fi

# --- Find bootstrap dir (accepts aws-bootstrap OR aws-bootstrap-main etc.) ---
BOOTSTRAP_DIR=""
# Prefer exact names first
for d in "$ROOT/../aws-bootstrap" "$ROOT/../aws-bootstrap-main"; do
  [[ -d "$d" ]] && BOOTSTRAP_DIR="$d" && break
done
# If still empty, pick the first dir that matches aws-bootstrap*
if [[ -z "$BOOTSTRAP_DIR" ]]; then
  CANDIDATE="$(cd "$ROOT/.." && ls -1d aws-bootstrap* 2>/dev/null | head -n1 || true)"
  [[ -n "$CANDIDATE" && -d "$ROOT/../$CANDIDATE" ]] && BOOTSTRAP_DIR="$ROOT/../$CANDIDATE"
fi
[[ -n "$BOOTSTRAP_DIR" ]] || { echo "ERROR: Could not find a sibling aws-bootstrap repo."; exit 1; }

# --- Try to read values from files FIRST (both formats supported) ---
BUCKET=""; REGION=""; DYNAMO=""
parse_from_file() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  # tolerate spaces/quotes/comments
  local b r d
  b="$(sed -nE 's/^[[:space:]]*bucket[[:space:]]*=[[:space:]]*"?([^"#]+)"?.*/\1/p' "$file" | head -1)"
  r="$(sed -nE 's/^[[:space:]]*region[[:space:]]*=[[:space:]]*"?([^"#]+)"?.*/\1/p' "$file" | head -1)"
  d="$(sed -nE 's/^[[:space:]]*dynamodb_table[[:space:]]*=[[:space:]]*"?([^"#]+)"?.*/\1/p' "$file" | head -1)"
  if [[ -n "$b" && -n "$r" && -n "$d" && "$b" != "UPDATE_ME" ]]; then
    BUCKET="$b"; REGION="$r"; DYNAMO="$d"
    echo "[eks] values from file: $file"
    return 0
  fi
  return 1
}

# 1) bootstrap main.tf (what many scripts write to)
parse_from_file "$BOOTSTRAP_DIR/main.tf" || \
# 2) bootstrap/resources/main.remote.tf (template some repos use)
parse_from_file "$BOOTSTRAP_DIR/resources/main.remote.tf" || true

# --- If still empty, read directly from bootstrap Terraform state (bulletproof) ---
if [[ -z "$BUCKET" || -z "$REGION" || -z "$DYNAMO" ]]; then
  echo "[eks] falling back to reading bootstrap Terraform state…"
  terraform -chdir="$BOOTSTRAP_DIR" init -reconfigure -input=false >/dev/null

  S3_ADDR="$(terraform -chdir="$BOOTSTRAP_DIR" state list | grep '^aws_s3_bucket\.' | head -1 || true)"
  DDB_ADDR="$(terraform -chdir="$BOOTSTRAP_DIR" state list | grep '^aws_dynamodb_table\.' | head -1 || true)"
  [[ -n "$S3_ADDR" && -n "$DDB_ADDR" ]] || { echo "ERROR: bootstrap state missing S3/Dynamo resources."; exit 1; }

  BUCKET="$(terraform -chdir="$BOOTSTRAP_DIR" state show "$S3_ADDR" | awk -F ' = ' '/^bucket = /{print $2; exit}' | tr -d '"')"
  DYNAMO="$(terraform -chdir="$BOOTSTRAP_DIR" state show "$DDB_ADDR" | awk -F ' = ' '/^name = /{print $2;   exit}' | tr -d '"')"
  REGION="$(terraform -chdir="$BOOTSTRAP_DIR" state show "$DDB_ADDR" | awk -F ' = ' '/^arn = /{print $2;    exit}' | sed -E 's/^"arn:aws:dynamodb:([^:]+):.*/\1/' | tr -d '"')"
fi

# --- Final sanity ---
if [[ -z "$BUCKET" || -z "$REGION" || -z "$DYNAMO" || "$BUCKET" == "UPDATE_ME" ]]; then
  echo "ERROR: Could not determine backend from bootstrap. "
  echo "Checked: $BOOTSTRAP_DIR/main.tf and $BOOTSTRAP_DIR/resources/main.remote.tf and TF state."
  exit 1
fi

echo "[eks] backend -> bucket=${BUCKET}  region=${REGION}  ddb=${DYNAMO}"

# --- Init / plan / apply ---
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
