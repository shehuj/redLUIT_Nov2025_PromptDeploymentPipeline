# Prompt Deployment Pipeline

A GitHub Actions CI/CD pipeline that processes structured prompt configurations, generates content using Amazon Bedrock (Claude 3), and deploys outputs to AWS S3 buckets. Infrastructure is managed with Terraform and secured with KMS encryption, CloudTrail audit logging, and GuardDuty threat detection.

![CI](https://github.com/shehuj/redLUIT_Nov2025_PromptDeploymentPipeline/actions/workflows/ci.yml/badge.svg)
![Deploy](https://github.com/shehuj/redLUIT_Nov2025_PromptDeploymentPipeline/actions/workflows/deploy.yml/badge.svg)

---

## Table of Contents

- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Setup](#setup)
- [Usage — Prompts](#usage--prompts)
- [Accessing Outputs & Validation](#accessing-outputs--validation)
- [Workflows](#workflows)
- [Supported Models](#supported-models)
- [Infrastructure](#infrastructure)
- [Security](#security)
- [Cleanup](#cleanup)
- [Cost Reference](#cost-reference)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

---

## Architecture

```
Pull Request (prompts/)
        │
        ▼
GitHub Actions: on_pull_request.yml
        │
        ▼
process_prompt.py ──► Amazon Bedrock (Claude 3)
        │
        ▼
S3 Beta Bucket: beta/outputs/
        │
  (PR approved)
        │
        ▼
GitHub Actions: on_merge.yml
        │
        ▼
S3 Prod Bucket: prod/outputs/
```

**Infrastructure** (Terraform-managed):

```
AWS Account
├── S3 Buckets          — beta, prod, access-logs, cloudtrail
├── KMS Keys            — beta + prod CMKs with key rotation
├── CloudTrail          — multi-region audit trail → S3 + CloudWatch Logs + SNS
├── CloudWatch          — log groups, 90-day retention
├── GuardDuty           — S3 threat detection (optional)
├── Security Hub        — CIS benchmark (optional)
└── IAM                 — least-privilege policy for GitHub Actions
```

---

## Project Structure

```
redLUIT_Nov2025_PromptDeploymentPipeline/
├── .github/
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── workflows/
│       ├── on_pull_request.yml     # Beta: runs on PR open/update
│       ├── on_merge.yml            # Prod: runs on merge to main
│       ├── ci.yml                  # Validate, lint, security scan
│       ├── deploy.yml              # Manual Terraform deploy
│       └── cleanup.yml             # Manual Terraform destroy (DESTROY confirm)
├── prompts/                        # Prompt configuration files (.json)
│   ├── welcome_prompt.json
│   └── summary_prompt.json
├── prompt_templates/               # Prompt templates with $variables
│   ├── welcome_email.txt
│   └── module_summary.txt
├── outputs/                        # Generated content (local runs)
├── scripts/
│   └── process_prompt.py           # Core processing script
├── terraform/
│   ├── main.tf                     # KMS, S3 buckets, access logs
│   ├── security.tf                 # CloudTrail, SNS, IAM, GuardDuty
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars
│   ├── .checkov.yml                # Documented security exceptions
│   └── .tfsec/config.yml           # Documented tfsec suppressions
├── requirements.txt
└── README.md
```

---

## Prerequisites

- **AWS account** with Bedrock Claude 3 model access enabled
- **GitHub repository** with Actions enabled
- **Terraform >= 1.5.0** (for local infrastructure management)
- **Python 3.11+** (for local prompt processing)
- **AWS CLI** configured locally

### Enable Bedrock Model Access

1. Open the [AWS Bedrock console](https://console.aws.amazon.com/bedrock)
2. Go to **Model access** → **Manage model access**
3. Enable **Claude 3 Sonnet**, **Claude 3.5 Sonnet**, and **Claude 3 Haiku**

---

## Setup

### 1. Clone the Repository

```bash
git clone https://github.com/shehuj/redLUIT_Nov2025_PromptDeploymentPipeline.git
cd redLUIT_Nov2025_PromptDeploymentPipeline
pip install -r requirements.txt
```

### 2. Deploy Infrastructure (Terraform)

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Terraform creates all S3 buckets, KMS keys, CloudTrail, IAM policy, and supporting resources. On first run it outputs the bucket names you need for GitHub secrets.

```bash
# View all outputs after apply
terraform output
```

### 3. Create an IAM User for GitHub Actions

Create an IAM user (`github-actions-prompt-pipeline`) and attach this policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["bedrock:InvokeModel"],
      "Resource": [
        "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0",
        "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-5-sonnet-20241022-v2:0",
        "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-haiku-20240307-v1:0"
      ]
    },
    {
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:GetObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::YOUR-BETA-BUCKET",
        "arn:aws:s3:::YOUR-BETA-BUCKET/*",
        "arn:aws:s3:::YOUR-PROD-BUCKET",
        "arn:aws:s3:::YOUR-PROD-BUCKET/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey"],
      "Resource": ["arn:aws:kms:us-east-1:ACCOUNT_ID:key/*"]
    }
  ]
}
```

Generate access keys for this user.

### 4. Configure GitHub Secrets

Go to **Settings → Secrets and variables → Actions** and add:

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key |
| `AWS_REGION` | AWS region (e.g. `us-east-1`) |
| `S3_BUCKET_BETA` | Beta bucket name from `terraform output beta_bucket_name` |
| `S3_BUCKET_PROD` | Prod bucket name from `terraform output prod_bucket_name` |

---

## Usage — Prompts

### Step 1: Create a Template

Add a file to `prompt_templates/`:

```text
# prompt_templates/newsletter.txt

You are a content writer creating a weekly newsletter.

Topic: $topic
Target Audience: $audience
Tone: $tone

Write a newsletter with:
- Engaging headline
- 3-4 key points
- Call to action
```

### Step 2: Create a Prompt Config

Add a `.json` file to `prompts/`:

```json
{
  "template": "newsletter.txt",
  "output_name": "weekly_newsletter_jan",
  "output_format": "html",
  "model_id": "anthropic.claude-3-sonnet-20240229-v1:0",
  "model_params": {
    "max_tokens": 2048,
    "temperature": 0.7,
    "top_p": 0.9
  },
  "variables": {
    "topic": "AI and Cloud Computing Trends",
    "audience": "Technical professionals",
    "tone": "Professional but conversational"
  }
}
```

**Configuration fields:**

| Field | Required | Description |
|-------|----------|-------------|
| `template` | Yes | Filename in `prompt_templates/` |
| `output_name` | Yes | Output filename (no extension) |
| `output_format` | No | `html` or `md` (default: `html`) |
| `model_id` | No | Bedrock model ID (default: Claude 3 Sonnet) |
| `model_params` | No | `max_tokens`, `temperature`, `top_p` |
| `variables` | Yes | `$variable` substitutions for the template |

### Step 3: Deploy via Pull Request

```bash
git checkout -b feature/new-prompt
# add files to prompts/ and prompt_templates/
git add prompts/ prompt_templates/
git commit -m "Add newsletter prompt"
git push origin feature/new-prompt
```

Open a Pull Request to `main`. The `on_pull_request.yml` workflow runs automatically, processes all prompts, and uploads to the beta bucket. Review the output before merging.

Merge the PR to push output to production.

### Local Testing

```bash
export AWS_REGION=us-east-1
export S3_BUCKET=your-beta-bucket
export S3_PREFIX=test/

# Single prompt
python scripts/process_prompt.py prompts/welcome_prompt.json

# All prompts
python scripts/process_prompt.py prompts/*.json
```

---

## Accessing Outputs & Validation

### View Generated Files in S3

```bash
# Beta outputs (after PR workflow)
aws s3 ls s3://YOUR-BETA-BUCKET/beta/outputs/

# Prod outputs (after merge workflow)
aws s3 ls s3://YOUR-PROD-BUCKET/prod/outputs/

# Download a file
aws s3 cp s3://YOUR-PROD-BUCKET/prod/outputs/weekly_newsletter_jan.html ./
```

### Validate Terraform Infrastructure

```bash
cd terraform

# See all deployed resource values
terraform output

# Full deployment summary
terraform output deployment_summary

# Specific outputs
terraform output beta_bucket_name
terraform output prod_bucket_name
```

### Verify AWS Resources Directly

```bash
# S3 buckets
aws s3 ls | grep prompt

# KMS keys
aws kms list-aliases | grep PromptDeploymentPipeline

# CloudTrail status
aws cloudtrail describe-trails --query 'trailList[?Name==`PromptDeploymentPipeline-audit-trail`]'

# CloudWatch log group
aws logs describe-log-groups --log-group-name-prefix "/aws/cloudtrail/PromptDeploymentPipeline"

# GuardDuty (if enabled)
aws guardduty list-detectors

# Confirm Terraform state matches live AWS
terraform plan   # should show: No changes
```

### View Workflow Run Output

1. Go to the **Actions** tab in GitHub
2. Click any workflow run
3. Each job shows step-by-step logs and a **Summary** with S3 upload details
4. Artifacts (generated files) are downloadable directly from the run summary for 5-30 days

---

## Workflows

### `on_pull_request.yml` — Beta Deployment

**Triggers:** PRs to `main` touching `prompts/`, `prompt_templates/`, or `scripts/`

1. Setup Python, install dependencies
2. Configure AWS credentials
3. Find all `prompts/*.json` configs
4. Invoke Bedrock for each prompt
5. Upload to `s3://BETA-BUCKET/beta/outputs/`
6. Comment on PR with results + artifact link

### `on_merge.yml` — Production Deployment

**Triggers:** Push to `main` touching `prompts/`, `prompt_templates/`, or `scripts/`

1. Setup Python, install dependencies
2. Configure AWS credentials
3. Verify S3 bucket access
4. Process all prompts
5. Upload to `s3://PROD-BUCKET/prod/outputs/`
6. Verify uploads and generate deployment summary
7. Upload artifacts (30-day retention)

### `ci.yml` — Continuous Integration

**Triggers:** All PRs and pushes to `main`

- Python syntax, flake8, black formatting
- Terraform fmt, init, validate
- JSON config validation (required fields, template existence)
- Checkov security scan
- Secret/credential pattern detection
- Project structure verification

### `deploy.yml` — Infrastructure Deploy

**Triggers:** Manual (`workflow_dispatch`)

Runs Terraform validate → security scan (Checkov + tfsec) → plan → approval → apply.

```
Actions → Deploy Infrastructure → Run workflow → select environment
```

### `cleanup.yml` — Infrastructure Destroy

**Triggers:** Manual only — requires typing `DESTROY` to confirm

1. Validates confirmation
2. Empties all versioned S3 buckets
3. Runs `terraform destroy`
4. Verifies resource removal

---

## Supported Models

| Model ID | Notes |
|----------|-------|
| `anthropic.claude-3-sonnet-20240229-v1:0` | Default — balanced cost/quality |
| `anthropic.claude-3-5-sonnet-20241022-v2:0` | Highest quality |
| `anthropic.claude-3-haiku-20240307-v1:0` | Fastest, lowest cost |

---

## Infrastructure

Managed by Terraform in the `terraform/` directory.

| Resource | Details |
|----------|---------|
| `aws_s3_bucket.beta` | Beta outputs, KMS-encrypted, versioned |
| `aws_s3_bucket.prod` | Prod outputs, KMS-encrypted, versioned |
| `aws_s3_bucket.access_logs` | Server access logs for all buckets |
| `aws_s3_bucket.cloudtrail` | CloudTrail log storage |
| `aws_kms_key.beta` | CMK for beta resources, 30-day deletion, auto-rotation |
| `aws_kms_key.prod` | CMK for prod resources, 30-day deletion, auto-rotation |
| `aws_cloudtrail.main` | Multi-region trail, log validation, CloudWatch + SNS |
| `aws_cloudwatch_log_group.cloudtrail` | 90-day retention, KMS-encrypted |
| `aws_sns_topic.cloudtrail` | CloudTrail event notifications |
| `aws_guardduty_detector.main` | S3 threat detection (toggle with `enable_guardduty`) |
| `aws_securityhub_account.main` | CIS benchmark (toggle with `enable_security_hub`) |

**Key Terraform variables** (set in `terraform.tfvars` or CLI `-var`):

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | `us-east-1` | Deployment region |
| `project_name` | — | Resource name prefix |
| `beta_bucket_name` | — | Beta S3 bucket name |
| `prod_bucket_name` | — | Prod S3 bucket name |
| `enable_cloudtrail` | `true` | Deploy CloudTrail |
| `enable_guardduty` | `false` | Deploy GuardDuty |
| `enable_security_hub` | `false` | Deploy Security Hub |
| `enable_public_access` | `false` | Open S3 for static website |
| `enable_website_hosting` | `false` | S3 static website config |

---

## Security

- **Encryption at rest** — All S3 buckets and CloudWatch log groups use customer-managed KMS keys with automatic rotation
- **Encryption in transit** — All S3 policies enforce TLS (`aws:SecureTransport`)
- **Audit logging** — CloudTrail multi-region trail captures all management and S3 data events; logs are stored in a dedicated encrypted bucket and streamed to CloudWatch Logs
- **No public access** — All buckets block public ACLs and policies by default (configurable for static hosting)
- **Least-privilege IAM** — GitHub Actions uses a scoped IAM policy with access only to required Bedrock models, S3 buckets, and KMS keys
- **Threat detection** — GuardDuty S3 protection (optional)
- **Compliance dashboard** — Security Hub with CIS AWS Foundations benchmark (optional)
- **Security scanning** — Checkov and tfsec run on every deploy; documented exceptions in `.checkov.yml` and `.tfsec/config.yml`

### Known Accepted Exceptions

| Finding | Reason |
|---------|--------|
| `aws-sns-enable-topic-encryption` | CloudTrail cannot publish to CMK-encrypted SNS topics (AWS service limitation). Data payload is notification-only; CloudTrail logs encrypted in S3. |
| `aws-iam-no-policy-wildcards` | `log-stream:*` required by CloudWatch Logs for CloudTrail integration — stream names are dynamically generated at runtime. Resource is scoped to a named log group ARN. |
| `CKV_AWS_144` | Cross-region S3 replication not required for this workload. |
| `CKV2_AWS_62` | S3 event notifications not used. |

---

## Cleanup

### Option 1: GitHub Actions (Recommended)

```
Actions → Cleanup Infrastructure → Run workflow
→ Type DESTROY → Run workflow
```

The workflow empties all versioned S3 buckets (versions + delete markers), then runs `terraform destroy`.

### Option 2: Local Terraform

```bash
# Back up important data first
aws s3 sync s3://YOUR-PROD-BUCKET ./backup/

# Verify account
aws sts get-caller-identity

# Empty versioned buckets (required before destroy)
BUCKET="YOUR-BETA-BUCKET"
aws s3api list-object-versions --bucket "$BUCKET" \
  --query 'Versions[].{Key:Key,VersionId:VersionId}' \
  --output json | \
  jq -r '.[] | "\(.Key) \(.VersionId)"' | \
  while read key vid; do
    aws s3api delete-object --bucket "$BUCKET" --key "$key" --version-id "$vid"
  done
aws s3 rm "s3://$BUCKET" --recursive

# Repeat for prod, access-logs, and cloudtrail buckets, then:
cd terraform
terraform destroy
```

### Important Notes

- **KMS keys** — AWS enforces a mandatory 30-day waiting period before deletion. Costs stop accruing immediately after scheduling deletion.
- **Deleted data is unrecoverable** — back up anything important before running cleanup.
- After destroy, check AWS Cost Explorer in 24-48 hours to confirm cost reduction.

---

## Cost Reference

### Bedrock (us-east-1)

| Model | Input (per 1K tokens) | Output (per 1K tokens) |
|-------|-----------------------|------------------------|
| Claude 3 Sonnet | $0.003 | $0.015 |
| Claude 3.5 Sonnet | $0.003 | $0.015 |
| Claude 3 Haiku | $0.00025 | $0.00125 |

Example: 1,000-word output (~1,500 tokens) with Claude 3 Sonnet ≈ **$0.024 per generation**

### S3

| Resource | Cost |
|----------|------|
| Storage | $0.023/GB/month |
| PUT requests | $0.005/1,000 |
| GET requests | $0.0004/1,000 |
| KMS keys | $1.00/key/month |
| CloudWatch Logs | $0.50/GB ingested |

---

## Troubleshooting

### Bedrock: Access Denied

```
Error: Could not invoke model: Access denied
```

1. Confirm Claude models are enabled in the Bedrock console under **Model access**
2. Verify IAM policy includes `bedrock:InvokeModel` for the specific model ARN
3. Confirm the region in the secret matches where models are enabled

### S3: Upload Failed

```
Error uploading to S3: Access Denied
```

1. Check `S3_BUCKET_BETA` / `S3_BUCKET_PROD` secrets match the actual bucket names (`terraform output beta_bucket_name`)
2. Verify IAM policy includes `s3:PutObject` and `kms:GenerateDataKey`
3. Confirm bucket exists in the correct region

### Template Variable Not Found

```
Warning: Variable 'user_name' not found in template
```

All `$variable` placeholders in the template must have a corresponding key in the `variables` object of the JSON config. Variables are case-sensitive.

### Workflow Not Triggering

Check the `paths:` filter in the workflow file matches the directory where you made changes. The `on_pull_request.yml` only triggers on changes under `prompts/`, `prompt_templates/`, or `scripts/`.

### Terraform: Resources Already Exist

```
Error: resource already exists
```

Import the existing resource or delete it manually:

```bash
# Option 1: Import
terraform import aws_kms_alias.beta alias/your-alias-name

# Option 2: Delete and let Terraform recreate
aws kms delete-alias --alias-name alias/your-alias-name
terraform apply
```

### Terraform: No Changes After Destroy/Rebuild

```bash
terraform plan   # should show resources to add
terraform apply
```

If state is stale: `terraform refresh` then re-plan.

### CI: Terraform Format Check Fails

```bash
cd terraform
terraform fmt -recursive
git add -u && git commit -m "Fix Terraform formatting"
```

### Cleanup: Bucket Not Empty Error

S3 versioned buckets cannot be deleted while they contain object versions. The cleanup workflow handles this automatically. To do it manually:

```bash
aws s3api list-object-versions --bucket BUCKET-NAME --output json | \
  jq -r '.Versions[]? | "\(.Key) \(.VersionId)"' | \
  while read key vid; do
    aws s3api delete-object --bucket BUCKET-NAME --key "$key" --version-id "$vid"
  done
aws s3 rm s3://BUCKET-NAME --recursive
```

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-prompt`
3. Add or modify files in `prompts/` and `prompt_templates/`
4. Test locally: `python scripts/process_prompt.py prompts/your_prompt.json`
5. Push and open a Pull Request — CI validates automatically
6. Review beta output from the PR workflow before merging

---

## Resources

- [Amazon Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)
- [Boto3 Bedrock Runtime](https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/bedrock-runtime.html)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
