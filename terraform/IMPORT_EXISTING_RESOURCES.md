# Importing Existing AWS Resources

If you're getting "BucketAlreadyExists" or other resource already exists errors, you can import existing resources into Terraform state.

## Import Existing S3 Buckets

```bash
# Import beta bucket
terraform import aws_s3_bucket.beta YOUR-BETA-BUCKET-NAME

# Import prod bucket
terraform import aws_s3_bucket.prod YOUR-PROD-BUCKET-NAME

# Import access logs bucket (if it exists)
terraform import aws_s3_bucket.access_logs YOUR-ACCESS-LOGS-BUCKET-NAME
```

## Find Your Bucket Names

```bash
# List all S3 buckets
aws s3 ls

# Or check your GitHub secrets
echo $S3_BUCKET_BETA
echo $S3_BUCKET_PROD
```

## Alternative: Use Different Bucket Names

Edit `terraform.tfvars`:

```hcl
beta_bucket_name = "my-unique-beta-bucket-$(date +%s)"
prod_bucket_name = "my-unique-prod-bucket-$(date +%s)"
```

## Alternative: Destroy and Recreate

**⚠️ WARNING: This will DELETE existing buckets and ALL their data!**

```bash
# Only do this if you're sure you want to delete existing buckets
aws s3 rb s3://YOUR-BETA-BUCKET-NAME --force
aws s3 rb s3://YOUR-PROD-BUCKET-NAME --force

# Then run terraform apply
terraform apply
```

## Recommended Approach

1. **Import existing buckets** (safest - keeps your data)
2. **Or use unique names** for new buckets
3. **Only destroy** if you're absolutely sure you don't need the data
