# Quick Setup Guide

This guide will help you set up the Prompt Deployment Pipeline in 15 minutes.

## Prerequisites Checklist

- [ ] AWS Account with admin access
- [ ] GitHub account
- [ ] AWS CLI installed locally
- [ ] Python 3.11+ installed

## Step-by-Step Setup

### Step 1: Enable Amazon Bedrock (5 minutes)

1. Log into AWS Console
2. Navigate to Amazon Bedrock
3. Select **Model access** from left menu
4. Click **Manage model access**
5. Check boxes for:
   - ✅ Anthropic Claude 3 Sonnet
   - ✅ Anthropic Claude 3 Haiku (optional)
6. Click **Request model access**
7. Wait for approval (usually instant)

### Step 2: Create S3 Buckets (3 minutes)

```bash
# Set your project name
PROJECT_NAME="myproject"
AWS_REGION="us-east-1"

# Create beta bucket
aws s3 mb s3://${PROJECT_NAME}-prompts-beta --region ${AWS_REGION}

# Create prod bucket
aws s3 mb s3://${PROJECT_NAME}-prompts-prod --region ${AWS_REGION}

# Enable versioning (recommended)
aws s3api put-bucket-versioning \
  --bucket ${PROJECT_NAME}-prompts-beta \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-versioning \
  --bucket ${PROJECT_NAME}-prompts-prod \
  --versioning-configuration Status=Enabled

# Enable static website hosting (optional)
aws s3 website s3://${PROJECT_NAME}-prompts-prod \
  --index-document index.html \
  --error-document error.html
```

### Step 3: Create IAM User (5 minutes)

#### Option A: Using AWS Console

1. Go to IAM → Users → Create user
2. Username: `github-actions-prompt-pipeline`
3. Skip adding to group
4. Attach policies directly → Create policy
5. Use JSON policy below
6. Create user and save access keys

#### Option B: Using AWS CLI

```bash
# Create IAM user
aws iam create-user --user-name github-actions-prompt-pipeline

# Create and attach policy
cat > bedrock-s3-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:ListFoundationModels"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::${PROJECT_NAME}-prompts-beta",
        "arn:aws:s3:::${PROJECT_NAME}-prompts-beta/*",
        "arn:aws:s3:::${PROJECT_NAME}-prompts-prod",
        "arn:aws:s3:::${PROJECT_NAME}-prompts-prod/*"
      ]
    }
  ]
}
EOF

# Create policy
aws iam create-policy \
  --policy-name BedrockS3PromptPipeline \
  --policy-document file://bedrock-s3-policy.json

# Get policy ARN
POLICY_ARN=$(aws iam list-policies --query 'Policies[?PolicyName==`BedrockS3PromptPipeline`].Arn' --output text)

# Attach policy to user
aws iam attach-user-policy \
  --user-name github-actions-prompt-pipeline \
  --policy-arn $POLICY_ARN

# Create access key
aws iam create-access-key --user-name github-actions-prompt-pipeline
```

**IMPORTANT:** Save the Access Key ID and Secret Access Key - you won't see them again!

### Step 4: Configure GitHub Secrets (2 minutes)

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** for each:

| Secret Name | Value |
|------------|-------|
| `AWS_ACCESS_KEY_ID` | Your IAM user access key ID |
| `AWS_SECRET_ACCESS_KEY` | Your IAM user secret access key |
| `AWS_REGION` | `us-east-1` (or your region) |
| `S3_BUCKET_BETA` | `myproject-prompts-beta` |
| `S3_BUCKET_PROD` | `myproject-prompts-prod` |

### Step 5: Test Locally (Optional, 5 minutes)

```bash
# Clone repository
git clone https://github.com/your-org/redLUIT_Nove2025_PromptDeploymentPipeline.git
cd redLUIT_Nove2025_PromptDeploymentPipeline

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Configure AWS credentials
aws configure

# Test processing a prompt
export S3_BUCKET=myproject-prompts-beta
export S3_PREFIX=test/
python scripts/process_prompt.py prompts/welcome_prompt.json
```

### Step 6: Create Your First Prompt (5 minutes)

1. Create a new branch:
```bash
git checkout -b feature/my-first-prompt
```

2. Create a template file `prompt_templates/greeting.txt`:
```text
You are a friendly assistant.

Write a personalized greeting for $name who works as a $role at $company.
Make it warm and professional.
```

3. Create a config file `prompts/greeting.json`:
```json
{
  "template": "greeting.txt",
  "output_name": "greeting_john",
  "output_format": "html",
  "variables": {
    "name": "John Doe",
    "role": "Software Engineer",
    "company": "TechCorp"
  }
}
```

4. Commit and push:
```bash
git add prompts/ prompt_templates/
git commit -m "Add greeting prompt"
git push origin feature/my-first-prompt
```

5. Create a Pull Request on GitHub

6. Watch the workflow run and check the PR comment for results!

## Verification Checklist

After setup, verify everything works:

- [ ] Bedrock model access granted
- [ ] S3 buckets created and accessible
- [ ] IAM user created with correct permissions
- [ ] GitHub secrets configured
- [ ] Pull request workflow runs successfully
- [ ] Generated content uploaded to beta bucket
- [ ] Merge workflow deploys to prod bucket

## Common Issues

### Issue: "Access denied" when invoking Bedrock

**Solution:**
1. Verify model access in Bedrock console
2. Check IAM policy includes `bedrock:InvokeModel`
3. Ensure you're using correct region

### Issue: "Bucket does not exist"

**Solution:**
1. Verify bucket name matches GitHub secret exactly
2. Check bucket exists in the correct region
3. Ensure IAM user has `s3:ListBucket` permission

### Issue: Workflow doesn't trigger

**Solution:**
1. Ensure changes are in `prompts/` or `prompt_templates/`
2. Check workflow file syntax
3. Verify branch name matches trigger configuration

## Next Steps

Once setup is complete:

1. ✅ Read the main [README.md](README.md) for detailed usage
2. ✅ Explore example prompts in `prompts/` directory
3. ✅ Customize templates for your use case
4. ✅ Set up S3 website hosting for public access
5. ✅ Configure CloudFront for HTTPS (optional)

## Cost Estimation

With this setup, typical monthly costs:

- **Bedrock:** $0.024 per 1000-word generation with Claude 3 Sonnet
- **S3 Storage:** $0.023 per GB/month
- **S3 Requests:** $0.005 per 1,000 PUT requests

**Example monthly cost for 100 generations:**
- Bedrock: 100 × $0.024 = $2.40
- S3 Storage: ~1 MB total = $0.00
- S3 Requests: 100 PUTs = $0.00
- **Total: ~$2.50/month**

## Security Reminders

- ✅ Never commit AWS credentials to git
- ✅ Use GitHub Secrets for all sensitive values
- ✅ Rotate IAM access keys every 90 days
- ✅ Enable MFA on AWS root account
- ✅ Review CloudTrail logs regularly
- ✅ Set up billing alerts in AWS

## Support

Need help?

- Check [README.md](README.md) for detailed documentation
- Review GitHub Actions logs
- Open an issue on GitHub
- Check AWS CloudWatch logs for Bedrock calls

## Success!

If you've completed all steps, you're ready to start generating content with Amazon Bedrock!

Try creating a PR with a new prompt configuration and watch the magic happen. 🎉
