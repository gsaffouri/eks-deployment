#!/usr/bin/env bash
set -euo pipefail

echo "Destroying EKS cluster from eks-deployment..."

# Auto-detect backend settings from aws-bootstrap
BOOTSTRAP_DIR="../aws-bootstrap/resources/main.remote.tf"

if [[ ! -f "$BOOTSTRAP_DIR" ]]; then
  echo "Cannot find aws-bootstrap backend config at: $BOOTSTRAP_DIR"
  exit 1
fi

BUCKET=$(grep 'bucket *= *' "$BOOTSTRAP_DIR" | head -1 | awk -F\" '{print $2}')
KEY=$(grep 'key *= *' "$BOOTSTRAP_DIR" | head -1 | awk -F\" '{print $2}')
REGION=$(grep 'region *= *' "$BOOTSTRAP_DIR" | head -1 | awk -F\" '{print $2}')
DYNAMO=$(grep 'dynamodb_table *= *' "$BOOTSTRAP_DIR" | head -1 | awk -F\" '{print $2}')

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
