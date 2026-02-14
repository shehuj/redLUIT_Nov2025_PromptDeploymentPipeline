# Terraform Backend Configuration for Remote State
# IMPORTANT: Backend configuration must be provided via backend-config file or CLI
# This prevents hardcoding sensitive information in version control
#
# Usage:
#   terraform init -backend-config="backend-config.tfvars"
#
# Or create backend-config.tfvars (DO NOT commit to git):
   bucket         = "ec2-shutdown-lambda-bucket"
   key            = "prompt-pipeline/terraform.tfstate"
   region         = "us-east-1"
   encrypt        = true
   dynamodb_table = "dyning_table"
   kms_key_id     = "arn:aws:kms:us-east-1:ACCOUNT_ID:key/KEY_ID"
#
# terraform {
#   backend "s3" {
#     # Configuration loaded from backend-config.tfvars
#   }
# }
#
# Prerequisites for remote state:
# 1. Create S3 bucket for state storage
# 2. Create DynamoDB table for state locking
# 3. Enable versioning on S3 bucket
# 4. Enable encryption with KMS
# 5. Set up bucket lifecycle policies
#
# Example setup:
#   aws s3api create-bucket \
#     --bucket your-terraform-state-bucket \
#     --region us-east-1 \
#     --create-bucket-configuration LocationConstraint=us-east-1
#
#   aws s3api put-bucket-versioning \
#     --bucket your-terraform-state-bucket \
#     --versioning-configuration Status=Enabled
#
#   aws dynamodb create-table \
#     --table-name terraform-state-lock \
#     --attribute-definitions AttributeName=LockID,AttributeType=S \
#     --key-schema AttributeName=LockID,KeyType=HASH \
#     --billing-mode PAY_PER_REQUEST \
#     --region us-east-1
