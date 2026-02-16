#!/bin/bash
# Quick Import Script for Existing Resources
# This will import all existing resources based on your error messages

set -e

echo "🔄 Quick Import Script for Existing Resources"
echo "=============================================="
echo ""

AWS_ACCOUNT_ID="615299732970"
AWS_REGION="us-east-1"

# Function to safely import (won't fail if already imported)
safe_import() {
    local resource=$1
    local id=$2

    echo -n "Importing $resource... "
    if terraform state show "$resource" &> /dev/null; then
        echo "✓ Already in state"
    else
        if terraform import "$resource" "$id" &> /dev/null; then
            echo "✓ Imported"
        else
            echo "⚠ Failed (resource may not exist)"
        fi
    fi
}

echo "Step 1: Import KMS Keys and Aliases"
echo "======================================"

# Get existing KMS key IDs from aliases
BETA_KEY=$(aws kms list-aliases --query "Aliases[?AliasName=='alias/PromptDeploymentPipeline-beta'].TargetKeyId" --output text 2>/dev/null || echo "")
PROD_KEY=$(aws kms list-aliases --query "Aliases[?AliasName=='alias/PromptDeploymentPipeline-prod'].TargetKeyId" --output text 2>/dev/null || echo "")

if [ -n "$BETA_KEY" ]; then
    echo "Found beta KMS key: $BETA_KEY"
    safe_import "aws_kms_key.beta" "$BETA_KEY"
    safe_import "aws_kms_alias.beta" "alias/PromptDeploymentPipeline-beta"
else
    echo "⚠ No beta KMS key found"
fi

if [ -n "$PROD_KEY" ]; then
    echo "Found prod KMS key: $PROD_KEY"
    safe_import "aws_kms_key.prod" "$PROD_KEY"
    safe_import "aws_kms_alias.prod" "alias/PromptDeploymentPipeline-prod"
else
    echo "⚠ No prod KMS key found"
fi

echo ""
echo "Step 2: Import S3 Buckets"
echo "======================================"

# Import S3 buckets
safe_import "aws_s3_bucket.beta" "prompt-deploy-pipeline-beta"
safe_import "aws_s3_bucket.prod" "prompt-deploy-pipeline-prod"
safe_import "aws_s3_bucket.access_logs" "prompt-deploy-pipeline-beta-access-logs"
safe_import "aws_s3_bucket.cloudtrail[0]" "prompt-deploy-pipeline-beta-cloudtrail"

echo ""
echo "Step 3: Import CloudWatch Resources"
echo "======================================"

safe_import "aws_cloudwatch_log_group.s3_access_logs" "/aws/s3/PromptDeploymentPipeline"

echo ""
echo "Step 4: Import OIDC Provider"
echo "======================================"

OIDC_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
safe_import "aws_iam_openid_connect_provider.github[0]" "$OIDC_ARN"

echo ""
echo "Step 5: Import Budget"
echo "======================================"

safe_import "aws_budgets_budget.monthly_cost[0]" "${AWS_ACCOUNT_ID}:PromptDeploymentPipeline-monthly-budget"

echo ""
echo "=============================================="
echo "✅ Import Complete!"
echo "=============================================="
echo ""
echo "Next steps:"
echo "1. Run: terraform plan"
echo "2. Review the plan"
echo "3. Run: terraform apply"
echo ""
