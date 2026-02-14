#!/bin/bash
# Import Existing AWS Resources into Terraform State
# This script imports resources that already exist in your AWS account

set -e  # Exit on error

echo "========================================="
echo "Terraform Resource Import Script"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}ERROR: AWS CLI is not configured. Run 'aws configure' first.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ AWS CLI configured${NC}"
echo ""

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=${AWS_REGION:-us-east-1}

echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "AWS Region: $AWS_REGION"
echo ""

# Function to import resource if it exists
import_if_exists() {
    local resource_type=$1
    local resource_name=$2
    local resource_id=$3

    echo -n "Importing $resource_type.$resource_name... "

    if terraform state show "$resource_type.$resource_name" &> /dev/null; then
        echo -e "${YELLOW}Already in state, skipping${NC}"
        return 0
    fi

    if terraform import "$resource_type.$resource_name" "$resource_id" &> /dev/null; then
        echo -e "${GREEN}✓ Success${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Resource doesn't exist or already imported${NC}"
        return 1
    fi
}

echo "========================================="
echo "Step 1: Import KMS Keys and Aliases"
echo "========================================="
echo ""

# Find existing KMS keys with our aliases
BETA_KEY_ID=$(aws kms list-aliases --query "Aliases[?AliasName=='alias/PromptDeploymentPipeline-beta'].TargetKeyId" --output text 2>/dev/null || echo "")
PROD_KEY_ID=$(aws kms list-aliases --query "Aliases[?AliasName=='alias/PromptDeploymentPipeline-prod'].TargetKeyId" --output text 2>/dev/null || echo "")

if [ -n "$BETA_KEY_ID" ]; then
    echo "Found existing KMS key for beta: $BETA_KEY_ID"
    import_if_exists "aws_kms_key" "beta" "$BETA_KEY_ID"
    import_if_exists "aws_kms_alias" "beta" "alias/PromptDeploymentPipeline-beta"
else
    echo -e "${YELLOW}⚠ No existing KMS key found for beta${NC}"
fi

if [ -n "$PROD_KEY_ID" ]; then
    echo "Found existing KMS key for prod: $PROD_KEY_ID"
    import_if_exists "aws_kms_key" "prod" "$PROD_KEY_ID"
    import_if_exists "aws_kms_alias" "prod" "alias/PromptDeploymentPipeline-prod"
else
    echo -e "${YELLOW}⚠ No existing KMS key found for prod${NC}"
fi

echo ""

echo "========================================="
echo "Step 2: Import S3 Buckets"
echo "========================================="
echo ""

# Get bucket names from terraform.tfvars or use defaults
BETA_BUCKET=$(grep 'beta_bucket_name' terraform.tfvars 2>/dev/null | cut -d'"' -f2 || echo "")
PROD_BUCKET=$(grep 'prod_bucket_name' terraform.tfvars 2>/dev/null | cut -d'"' -f2 || echo "")

if [ -z "$BETA_BUCKET" ]; then
    echo "Enter beta bucket name (or press Enter to skip):"
    read BETA_BUCKET
fi

if [ -z "$PROD_BUCKET" ]; then
    echo "Enter prod bucket name (or press Enter to skip):"
    read PROD_BUCKET
fi

if [ -n "$BETA_BUCKET" ]; then
    echo "Importing beta bucket: $BETA_BUCKET"
    import_if_exists "aws_s3_bucket" "beta" "$BETA_BUCKET"

    # Import bucket configurations
    import_if_exists "aws_s3_bucket_versioning" "beta" "$BETA_BUCKET"
    import_if_exists "aws_s3_bucket_server_side_encryption_configuration" "beta" "$BETA_BUCKET"
    import_if_exists "aws_s3_bucket_lifecycle_configuration" "beta" "$BETA_BUCKET"
    import_if_exists "aws_s3_bucket_public_access_block" "beta" "$BETA_BUCKET"
    import_if_exists "aws_s3_bucket_logging" "beta" "$BETA_BUCKET"
fi

if [ -n "$PROD_BUCKET" ]; then
    echo "Importing prod bucket: $PROD_BUCKET"
    import_if_exists "aws_s3_bucket" "prod" "$PROD_BUCKET"

    # Import bucket configurations
    import_if_exists "aws_s3_bucket_versioning" "prod" "$PROD_BUCKET"
    import_if_exists "aws_s3_bucket_server_side_encryption_configuration" "prod" "$PROD_BUCKET"
    import_if_exists "aws_s3_bucket_lifecycle_configuration" "prod" "$PROD_BUCKET"
    import_if_exists "aws_s3_bucket_public_access_block" "prod" "$PROD_BUCKET"
    import_if_exists "aws_s3_bucket_logging" "prod" "$PROD_BUCKET"
fi

echo ""

echo "========================================="
echo "Step 3: Import GitHub OIDC Provider"
echo "========================================="
echo ""

# Check if OIDC provider exists
OIDC_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN" &> /dev/null; then
    echo "Found existing GitHub OIDC provider"
    import_if_exists "aws_iam_openid_connect_provider" "github[0]" "$OIDC_ARN"
else
    echo -e "${YELLOW}⚠ No existing GitHub OIDC provider found${NC}"
fi

echo ""

echo "========================================="
echo "Step 4: Import CloudWatch Resources"
echo "========================================="
echo ""

LOG_GROUP="/aws/s3/PromptDeploymentPipeline"
if aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" &> /dev/null; then
    import_if_exists "aws_cloudwatch_log_group" "s3_access_logs" "$LOG_GROUP"
fi

echo ""

echo "========================================="
echo "Summary"
echo "========================================="
echo ""
echo -e "${GREEN}Import process complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Run 'terraform plan' to see remaining changes"
echo "2. Review the plan carefully"
echo "3. Run 'terraform apply' to apply remaining changes"
echo ""
echo "Note: Some resources may still show as 'to be created' if they don't exist yet."
echo "This is normal for optional resources."
