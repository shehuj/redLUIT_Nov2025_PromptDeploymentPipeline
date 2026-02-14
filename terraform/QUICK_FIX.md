# Quick Fix for Existing Resources

Based on your errors, here are the **exact commands** to import your existing resources:

## 🚀 Quick Solution (Run these commands)

```bash
cd terraform

# Import KMS Keys and Aliases
terraform import aws_kms_key.beta $(aws kms list-aliases --query "Aliases[?AliasName=='alias/PromptDeploymentPipeline-beta'].TargetKeyId" --output text)
terraform import aws_kms_alias.beta alias/PromptDeploymentPipeline-beta

terraform import aws_kms_key.prod $(aws kms list-aliases --query "Aliases[?AliasName=='alias/PromptDeploymentPipeline-prod'].TargetKeyId" --output text)
terraform import aws_kms_alias.prod alias/PromptDeploymentPipeline-prod

# Import OIDC Provider
terraform import 'aws_iam_openid_connect_provider.github[0]' arn:aws:iam::615299732970:oidc-provider/token.actions.githubusercontent.com

# Import S3 Buckets (replace *** with your actual bucket names)
# Find your bucket names first:
aws s3 ls | grep prompt

# Then import (replace BETA-BUCKET-NAME and PROD-BUCKET-NAME):
terraform import aws_s3_bucket.beta BETA-BUCKET-NAME
terraform import aws_s3_bucket.prod PROD-BUCKET-NAME

# After importing, apply
terraform plan
terraform apply
```

## 📋 Or Use the Automated Script

```bash
cd terraform
./import-existing-resources.sh
```

## 🔍 Find Your Bucket Names

```bash
# List all S3 buckets
aws s3 ls

# Or check GitHub secrets
echo $S3_BUCKET_BETA
echo $S3_BUCKET_PROD
```

## ✅ What's Been Fixed

1. **CloudWatch Metric Filter** - Disabled (S3 logs don't go to CloudWatch anyway)
2. **Import Script Created** - `import-existing-resources.sh`
3. **All Terraform formatted** - Ready to deploy

## 🎯 After Importing

```bash
terraform plan    # Should show only new resources
terraform apply   # Create remaining resources
```

## ⚠️ Alternative: Start Fresh

If you want to start completely fresh (⚠️ **deletes existing resources**):

```bash
# Delete existing KMS aliases (keys will be scheduled for deletion)
aws kms delete-alias --alias-name alias/PromptDeploymentPipeline-beta
aws kms delete-alias --alias-name alias/PromptDeploymentPipeline-prod

# Delete OIDC provider (if you created it manually)
aws iam delete-open-id-connect-provider \
  --open-id-connect-provider-arn arn:aws:iam::615299732970:oidc-provider/token.actions.githubusercontent.com

# Then run terraform apply to create everything fresh
terraform apply
```

## 💡 Recommended Approach

**Option 1:** Import existing resources (safest)
```bash
./import-existing-resources.sh
terraform apply
```

**Option 2:** Delete aliases and let Terraform recreate
```bash
aws kms delete-alias --alias-name alias/PromptDeploymentPipeline-beta
aws kms delete-alias --alias-name alias/PromptDeploymentPipeline-prod
terraform apply
```

Choose Option 1 if you want to keep existing keys, Option 2 if you're okay with new keys.
