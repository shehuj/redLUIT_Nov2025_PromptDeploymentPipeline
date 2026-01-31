# GitHub Secrets Configuration Guide

Before you can use the Prompt Deployment Pipeline workflows, you must configure the required GitHub secrets.

## Required GitHub Secrets

Navigate to your repository: **Settings → Secrets and variables → Actions → New repository secret**

### 1. AWS Credentials

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | AWS IAM user access key | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM user secret key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `AWS_REGION` | AWS region for Bedrock and S3 | `us-east-1` |

### 2. S3 Bucket Names

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `S3_BUCKET_BETA` | Beta environment S3 bucket | `myproject-prompts-beta` |
| `S3_BUCKET_PROD` | Production environment S3 bucket | `myproject-prompts-prod` |

## Setup Order

### Step 1: Deploy Infrastructure First

Before setting S3 bucket secrets, you need to deploy the infrastructure:

1. Set AWS credentials (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION)
2. Run the **Deploy Pipeline Infrastructure** workflow
3. Note the bucket names from the workflow outputs

### Step 2: Configure S3 Bucket Secrets

After infrastructure deployment:

1. Copy the bucket names from the Terraform outputs
2. Add `S3_BUCKET_BETA` secret with the beta bucket name
3. Add `S3_BUCKET_PROD` secret with the prod bucket name

## How to Add Secrets

### Via GitHub Web Interface

1. Go to your repository on GitHub
2. Click **Settings** (top menu)
3. In the left sidebar, click **Secrets and variables** → **Actions**
4. Click **New repository secret**
5. Enter:
   - **Name**: Secret name (e.g., `AWS_ACCESS_KEY_ID`)
   - **Secret**: The actual value
6. Click **Add secret**
7. Repeat for all required secrets

### Via GitHub CLI

```bash
# Set AWS credentials
gh secret set AWS_ACCESS_KEY_ID
gh secret set AWS_SECRET_ACCESS_KEY
gh secret set AWS_REGION

# Set S3 bucket names (after infrastructure deployment)
gh secret set S3_BUCKET_BETA
gh secret set S3_BUCKET_PROD
```

When prompted, paste the secret value and press Enter.

## Verification

After adding all secrets, run the **Validate Pipeline Setup** workflow:

```
Actions → Validate Pipeline Setup → Run workflow
```

This will verify:
- ✅ AWS credentials are valid
- ✅ Bedrock access is enabled
- ✅ S3 buckets exist and are accessible
- ✅ All required secrets are configured

## Troubleshooting

### "Missing required GitHub secrets" Error

**Error in workflow:**
```
❌ Missing required GitHub secrets:
S3_BUCKET_BETA
```

**Solution:**
1. Ensure you've deployed infrastructure first (Deploy Infrastructure workflow)
2. Get bucket name from Terraform outputs
3. Add the secret in repository settings

### "Access Denied" Errors

**Possible causes:**
- AWS credentials are incorrect
- IAM user doesn't have required permissions
- AWS region mismatch

**Solution:**
1. Verify AWS credentials are correct
2. Check IAM policy includes:
   - `bedrock:InvokeModel`
   - `s3:PutObject`, `s3:GetObject`, `s3:ListBucket`
3. Ensure region matches where buckets were created

### Secrets Not Updating

**Issue:** Updated secret but workflow still uses old value

**Solution:**
- Secrets are cached per workflow run
- Re-run the workflow after updating secrets
- Clear any saved artifacts that might contain old values

## Security Best Practices

### ✅ DO:
- Rotate AWS access keys every 90 days
- Use dedicated IAM user for GitHub Actions (not root account)
- Follow principle of least privilege
- Enable MFA on AWS root account
- Review CloudTrail logs regularly

### ❌ DON'T:
- Never commit secrets to git
- Never share secrets in PR comments
- Never use production credentials in beta
- Never hardcode bucket names or regions in code
- Never use AWS root account credentials

## Next Steps

After configuring secrets:

1. ✅ Run **Validate Pipeline Setup** workflow
2. ✅ Create a test prompt in `prompts/` directory
3. ✅ Submit a pull request
4. ✅ Verify beta deployment works
5. ✅ Merge to deploy to production

## References

- [DEPLOYMENT.md](DEPLOYMENT.md) - Complete deployment guide
- [SETUP_GUIDE.md](SETUP_GUIDE.md) - Quick setup instructions
- [README.md](README.md) - Main documentation
- [GitHub Secrets Documentation](https://docs.github.com/en/actions/security-guides/encrypted-secrets)

## Support

If you encounter issues:
1. Check workflow logs in GitHub Actions
2. Run the validation workflow
3. Review the error messages
4. Verify all secrets are correctly named (case-sensitive)
5. Check IAM policy permissions

---

**Important:** All secrets are encrypted and only exposed to GitHub Actions workflows. They are never visible in logs or to repository collaborators.
