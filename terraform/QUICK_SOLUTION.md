# 🚀 Quick Solution for "Already Exists" Errors

You have existing resources that conflict with Terraform. Here are **TWO QUICK SOLUTIONS**:

---

## ✅ **Solution 1: Delete Existing Aliases (FASTEST - Recommended)**

This deletes the KMS aliases and lets Terraform recreate them fresh. **The safest and fastest option.**

```bash
cd terraform

# Delete existing KMS aliases
aws kms delete-alias --alias-name alias/PromptDeploymentPipeline-beta
aws kms delete-alias --alias-name alias/PromptDeploymentPipeline-prod

# Delete existing CloudWatch log group
aws logs delete-log-group --log-group-name /aws/s3/PromptDeploymentPipeline

# Delete existing budget
aws budgets delete-budget \
  --account-id 615299732970 \
  --budget-name PromptDeploymentPipeline-monthly-budget

# Now run Terraform apply again
terraform apply
```

**Why this works**:
- KMS keys will stay (new aliases will point to them)
- S3 buckets will stay (Terraform will manage them)
- Everything else recreates cleanly

**Time**: ~2 minutes

---

## ✅ **Solution 2: Import Existing Resources**

This imports existing resources into Terraform state.

```bash
cd terraform

# Run the import script
./quick-import.sh

# Then apply
terraform apply
```

**Why this works**: Terraform will now know about existing resources

**Time**: ~5 minutes

---

## 📋 **Which Solution Should I Use?**

### **Use Solution 1 if**:
- ✅ You want the fastest fix
- ✅ You're okay with deleting aliases (they recreate instantly)
- ✅ You want clean state
- ✅ **RECOMMENDED for most cases**

### **Use Solution 2 if**:
- You want to preserve exact resource IDs
- You want to keep everything as-is
- You prefer import over delete

---

## 🎯 **Step-by-Step for Solution 1 (Recommended)**

Copy and paste these commands:

```bash
# Navigate to terraform directory
cd terraform

# Delete conflicting resources
echo "🗑️  Deleting existing aliases..."
aws kms delete-alias --alias-name alias/PromptDeploymentPipeline-beta 2>/dev/null || echo "Beta alias doesn't exist"
aws kms delete-alias --alias-name alias/PromptDeploymentPipeline-prod 2>/dev/null || echo "Prod alias doesn't exist"

echo "🗑️  Deleting existing CloudWatch log group..."
aws logs delete-log-group --log-group-name /aws/s3/PromptDeploymentPipeline 2>/dev/null || echo "Log group doesn't exist"

echo "🗑️  Deleting existing budget..."
aws budgets delete-budget \
  --account-id 615299732970 \
  --budget-name PromptDeploymentPipeline-monthly-budget 2>/dev/null || echo "Budget doesn't exist"

echo "✅ Cleanup complete! Now running terraform apply..."

# Apply Terraform
terraform apply
```

---

## ⚡ **One-Liner Solution**

```bash
cd terraform && \
aws kms delete-alias --alias-name alias/PromptDeploymentPipeline-beta 2>/dev/null; \
aws kms delete-alias --alias-name alias/PromptDeploymentPipeline-prod 2>/dev/null; \
aws logs delete-log-group --log-group-name /aws/s3/PromptDeploymentPipeline 2>/dev/null; \
aws budgets delete-budget --account-id 615299732970 --budget-name PromptDeploymentPipeline-monthly-budget 2>/dev/null; \
terraform apply
```

---

## ❓ **What About the S3 Buckets and OIDC Provider?**

These are **intentionally left alone** because:

- **S3 Buckets**: Contain your data - Terraform will manage them without recreating
- **OIDC Provider**: Shared resource - safe to leave as-is

Terraform will either:
1. Import them automatically on next apply, OR
2. Show them as already managed

---

## 🔍 **Verify It Worked**

After running Solution 1 or 2:

```bash
# This should show all green (no errors)
terraform plan

# Then apply
terraform apply
```

You should see:
```
✅ No errors
✅ Resources created or updated
✅ Apply complete!
```

---

## 🆘 **Still Getting Errors?**

If you still see "BucketAlreadyExists" for S3 buckets:

```bash
# Import the S3 buckets manually
terraform import aws_s3_bucket.beta prompt-deploy-pipeline-beta
terraform import aws_s3_bucket.prod prompt-deploy-pipeline-prod
terraform import aws_s3_bucket.access_logs prompt-deploy-pipeline-beta-access-logs

# Then apply
terraform apply
```

---

## 💡 **Pro Tip: Add to Makefile**

Add this to your Makefile for future use:

```makefile
tf-cleanup-aliases: ## Delete existing KMS aliases and rerun terraform
	aws kms delete-alias --alias-name alias/PromptDeploymentPipeline-beta || true
	aws kms delete-alias --alias-name alias/PromptDeploymentPipeline-prod || true
	aws logs delete-log-group --log-group-name /aws/s3/PromptDeploymentPipeline || true
	aws budgets delete-budget --account-id 615299732970 --budget-name PromptDeploymentPipeline-monthly-budget || true
	@echo "✅ Cleanup complete! Run 'make tf-apply' to continue"
```

Then just run:
```bash
make tf-cleanup-aliases
make tf-apply
```

---

## ✅ **Success Criteria**

After running the solution, you should see:

```
✅ terraform plan shows no errors
✅ terraform apply completes successfully
✅ All resources created or updated
✅ No "AlreadyExists" errors
```

---

**RECOMMENDED: Use Solution 1 (delete aliases) - it's faster and cleaner!** 🚀
