#!/usr/bin/env bash
set -euo pipefail

REPO="Vuong-Bach/infra-102"
BOOTSTRAP_DIR="$(cd "$(dirname "$0")/../bootstrap" && pwd)"

# Check dependencies
for cmd in gh terraform; do
  if ! command -v $cmd &>/dev/null; then
    echo "Error: $cmd not found" >&2
    exit 1
  fi
done

echo "Reading bootstrap outputs..."
cd "$BOOTSTRAP_DIR"

PLAN_ROLE_ARN=$(terraform output -raw plan_role_arn)
APPLY_ROLE_ARN=$(terraform output -raw apply_role_arn)
STATE_BUCKET=$(terraform output -raw state_bucket)
STATE_LOCK_TABLE=$(terraform output -raw state_lock_table)
AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || grep 'aws_region' terraform.tfvars | cut -d'"' -f2)

echo "Setting GitHub secrets for $REPO..."

gh secret set TF_PLAN_ROLE_ARN  --body "$PLAN_ROLE_ARN"  --repo "$REPO"
gh secret set TF_APPLY_ROLE_ARN --body "$APPLY_ROLE_ARN" --repo "$REPO"
gh secret set TF_STATE_BUCKET   --body "$STATE_BUCKET"   --repo "$REPO"
gh secret set TF_STATE_LOCK_TABLE --body "$STATE_LOCK_TABLE" --repo "$REPO"
gh secret set AWS_REGION        --body "$AWS_REGION"     --repo "$REPO"

echo "Done. Secrets set:"
gh secret list --repo "$REPO"
