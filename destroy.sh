#!/usr/bin/env bash
set -euo pipefail

echo "Destroying EKS cluster from eks-deployment..."

# Auto-detect backend settings from aws-bootstrap
BOOTSTRAP_DIR="../aws-bootstrap/resources/main.remote.tf"

if [[ ! -f "$BOOTSTRAP_DIR" ]]; then
  echo "Cannot find aws-bootstrap backend config at: $BOOTSTRAP_DIR"
  exit 1
fi

# robust extraction (works with "value", 'value', or unquoted)
BUCKET=$(sed -nE 's/.*bucket *= *["'\'']?([^"'\'' ]+)["'\'']?.*/\1/p' "$BOOTSTRAP_TF" | head -1)
REGION=$(sed -nE 's/.*region *= *["'\'']?([^"'\'' ]+)["'\'']?.*/\1/p' "$BOOTSTRAP_TF" | head -1)
DYNAMO=$(sed -nE 's/.*dynamodb_table *= *["'\'']?([^"'\'' ]+)["'\'']?.*/\1/p' "$BOOTSTRAP_TF" | head -1)


echo "Backend settings loaded:"
echo "  Bucket: $BUCKET"
echo "  Key: $KEY"
echo "  Region: $REGION"
echo "  DynamoDB: $DYNAMO"
echo

terraform init \
  -backend-config="bucket=$BUCKET" \
  -backend-config="key=$KEY" \
  -backend-config="region=$REGION" \
  -backend-config="dynamodb_table=$DYNAMO" \
  -input=false

terraform destroy -auto-approve -input=false

echo "EKS cluster destroyed successfully!"
