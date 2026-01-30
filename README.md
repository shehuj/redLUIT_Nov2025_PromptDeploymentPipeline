# Prompt Deployment Pipeline

A GitHub-based CI/CD pipeline that processes structured prompt configurations, generates content using Amazon Bedrock, and deploys outputs to S3 buckets configured for static website hosting.

## Overview

This pipeline automates the process of:
1. Reading structured prompt configuration files
2. Loading and rendering prompt templates with variables
3. Sending prompts to Amazon Bedrock for AI-powered content generation
4. Uploading generated content to S3 with environment-based prefixes (beta/prod)

## Architecture

```
┌─────────────────┐
│  Pull Request   │
│   (prompts/)    │
└────────┬────────┘
         │
         ▼
┌─────────────────────────┐
│  GitHub Actions         │
│  - on_pull_request.yml  │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐      ┌──────────────────┐
│  process_prompt.py      │─────▶│  Amazon Bedrock  │
│  - Load config & template│      │  (Claude 3)      │
│  - Render prompt        │      └──────────────────┘
│  - Invoke Bedrock       │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│  S3 Bucket (Beta)       │
│  - beta/outputs/        │
└─────────────────────────┘

┌─────────────────┐
│  Merge to Main  │
└────────┬────────┘
         │
         ▼
┌─────────────────────────┐
│  GitHub Actions         │
│  - on_merge.yml         │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│  S3 Bucket (Prod)       │
│  - prod/outputs/        │
└─────────────────────────┘
```

## Project Structure

```
redLUIT_Nove2025_PromptDeploymentPipeline/
├── .github/
│   └── workflows/
│       ├── on_pull_request.yml    # Beta deployment workflow
│       └── on_merge.yml            # Production deployment workflow
├── prompts/                        # Prompt configuration files
│   ├── welcome_prompt.json
│   └── summary_prompt.json
├── prompt_templates/               # Template files with variables
│   ├── welcome_email.txt
│   └── module_summary.txt
├── outputs/                        # Generated content (local)
├── scripts/
│   └── process_prompt.py          # Main processing script
├── requirements.txt               # Python dependencies
└── README.md                      # This file
```

## Setup

### 1. Prerequisites

- AWS Account with access to:
  - Amazon Bedrock (Claude 3 Sonnet enabled)
  - S3 (two buckets for beta and prod)
  - IAM (credentials with appropriate permissions)
- GitHub repository

### 2. AWS Setup

#### Enable Amazon Bedrock

1. Navigate to AWS Bedrock console
2. Enable model access for Claude 3 Sonnet
3. Wait for approval (usually immediate for Claude models)

#### Create S3 Buckets

```bash
# Create beta bucket
aws s3 mb s3://your-project-beta-bucket --region us-east-1

# Create prod bucket
aws s3 mb s3://your-project-prod-bucket --region us-east-1

# Enable static website hosting (optional)
aws s3 website s3://your-project-beta-bucket \
  --index-document index.html \
  --error-document error.html

aws s3 website s3://your-project-prod-bucket \
  --index-document index.html \
  --error-document error.html
```

#### Configure Bucket Policies

For public static website hosting:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::your-project-prod-bucket/*"
    }
  ]
}
```

#### Create IAM User for GitHub Actions

1. Create IAM user: `github-actions-prompt-pipeline`
2. Attach policy with permissions:

```json
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
        "arn:aws:s3:::your-project-beta-bucket/*",
        "arn:aws:s3:::your-project-beta-bucket",
        "arn:aws:s3:::your-project-prod-bucket/*",
        "arn:aws:s3:::your-project-prod-bucket"
      ]
    }
  ]
}
```

3. Generate access keys

### 3. GitHub Secrets

Add the following secrets to your GitHub repository (Settings → Secrets and variables → Actions):

| Secret Name | Description | Example |
|------------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | AWS access key | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `AWS_REGION` | AWS region | `us-east-1` |
| `S3_BUCKET_BETA` | Beta S3 bucket name | `your-project-beta-bucket` |
| `S3_BUCKET_PROD` | Prod S3 bucket name | `your-project-prod-bucket` |

### 4. Local Development Setup

```bash
# Clone repository
git clone https://github.com/your-org/redLUIT_Nove2025_PromptDeploymentPipeline.git
cd redLUIT_Nove2025_PromptDeploymentPipeline

# Install dependencies
pip install -r requirements.txt

# Configure AWS credentials (if not already configured)
aws configure
```

## Usage

### Creating Prompt Configurations

1. **Create a prompt template** in `prompt_templates/`:

```text
# prompt_templates/newsletter.txt

You are a content writer creating a weekly newsletter.

Topic: $topic
Target Audience: $audience
Tone: $tone

Create a newsletter with:
- Engaging headline
- 3-4 key points
- Call to action
```

2. **Create a configuration file** in `prompts/`:

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

### Configuration Fields

| Field | Required | Description |
|-------|----------|-------------|
| `template` | Yes | Template filename in `prompt_templates/` |
| `output_name` | Yes | Output filename (without extension) |
| `output_format` | No | Output format: `html` or `md` (default: `html`) |
| `model_id` | No | Bedrock model ID (default: Claude 3 Sonnet) |
| `model_params` | No | Model parameters (max_tokens, temperature, top_p) |
| `variables` | Yes | Dictionary of variables to substitute in template |

### Deployment Process

#### Beta Deployment (Pull Request)

1. Create a new branch:
```bash
git checkout -b feature/new-prompt
```

2. Add your prompt config and template files

3. Commit and push:
```bash
git add prompts/ prompt_templates/
git commit -m "Add new newsletter prompt"
git push origin feature/new-prompt
```

4. Create a Pull Request to `main`

5. GitHub Actions will:
   - Process all prompts in `prompts/` directory
   - Upload outputs to `s3://beta-bucket/beta/outputs/`
   - Comment on PR with deployment details

6. Review generated content in beta environment

#### Production Deployment (Merge)

1. Merge the Pull Request to `main`

2. GitHub Actions will:
   - Process all prompts
   - Upload outputs to `s3://prod-bucket/prod/outputs/`
   - Create deployment summary

3. Access production content via S3 URLs

### Local Testing

Test prompt processing locally before committing:

```bash
# Set environment variables
export AWS_REGION=us-east-1
export S3_BUCKET=your-project-beta-bucket
export S3_PREFIX=test/

# Process a single prompt
python scripts/process_prompt.py prompts/welcome_prompt.json

# Process multiple prompts
python scripts/process_prompt.py prompts/*.json
```

## Supported Models

The pipeline supports multiple Bedrock models:

| Model ID | Description | Best For |
|----------|-------------|----------|
| `anthropic.claude-3-sonnet-20240229-v1:0` | Claude 3 Sonnet (default) | Balanced performance and cost |
| `anthropic.claude-3-5-sonnet-20241022-v2:0` | Claude 3.5 Sonnet | Best performance |
| `anthropic.claude-3-haiku-20240307-v1:0` | Claude 3 Haiku | Fast, cost-effective |
| `amazon.titan-text-express-v1` | Amazon Titan Text Express | Simple tasks |

## Workflow Details

### Pull Request Workflow (`on_pull_request.yml`)

**Triggers:**
- Pull requests to `main` branch
- Changes in `prompts/`, `prompt_templates/`, or `scripts/`

**Steps:**
1. Checkout code
2. Setup Python environment
3. Install dependencies
4. Configure AWS credentials
5. Find all prompt configurations
6. Process each prompt with Bedrock
7. Upload to S3 with `beta/` prefix
8. Upload artifacts to GitHub
9. Comment on PR with results

### Merge Workflow (`on_merge.yml`)

**Triggers:**
- Push to `main` branch
- Changes in `prompts/`, `prompt_templates/`, or `scripts/`

**Steps:**
1. Checkout code
2. Setup Python environment
3. Install dependencies
4. Configure AWS credentials
5. Verify S3 bucket access
6. Find all prompt configurations
7. Process each prompt with Bedrock
8. Upload to S3 with `prod/` prefix
9. Verify uploads
10. Upload artifacts to GitHub (30-day retention)
11. Generate deployment summary

## Security Best Practices

### Credential Management

- ✅ Use GitHub Secrets for all credentials
- ✅ Never commit AWS credentials to repository
- ✅ Use IAM roles with least privilege
- ✅ Rotate access keys regularly

### S3 Bucket Security

- ✅ Enable bucket versioning
- ✅ Enable server-side encryption
- ✅ Use bucket policies to restrict access
- ✅ Enable CloudTrail logging
- ✅ Consider using CloudFront for public access

### Bedrock Security

- ✅ Use IAM policies to limit model access
- ✅ Monitor usage with CloudWatch
- ✅ Set up billing alerts
- ✅ Review generated content for sensitive data

## Cost Considerations

### Amazon Bedrock Pricing (us-east-1)

| Model | Input (per 1K tokens) | Output (per 1K tokens) |
|-------|----------------------|------------------------|
| Claude 3 Sonnet | $0.003 | $0.015 |
| Claude 3.5 Sonnet | $0.003 | $0.015 |
| Claude 3 Haiku | $0.00025 | $0.00125 |

**Example:** Generating a 1000-word document (~1500 tokens) with Claude 3 Sonnet:
- Input: 500 tokens × $0.003 = $0.0015
- Output: 1500 tokens × $0.015 = $0.0225
- **Total: ~$0.024 per generation**

### S3 Pricing

- Storage: $0.023 per GB/month
- PUT requests: $0.005 per 1,000 requests
- GET requests: $0.0004 per 1,000 requests

## Troubleshooting

### Bedrock Access Denied

```
Error: Could not invoke model: Access denied
```

**Solution:**
1. Verify model is enabled in Bedrock console
2. Check IAM permissions include `bedrock:InvokeModel`
3. Confirm correct region is specified

### S3 Upload Failed

```
Error uploading to S3: Access Denied
```

**Solution:**
1. Verify S3 bucket name is correct
2. Check IAM permissions include `s3:PutObject`
3. Ensure bucket exists in specified region

### Template Variable Not Found

```
Warning: Variable 'user_name' not found in template
```

**Solution:**
- Ensure all variables in template are defined in config `variables` object
- Use `$variable` syntax in templates
- Variables are case-sensitive

### Workflow Not Triggering

**Solution:**
1. Check workflow file paths in `on.pull_request.paths`
2. Verify changes are in monitored directories
3. Check branch name matches trigger configuration

## Advanced Usage

### Custom Output Processing

Modify `process_prompt.py` to add custom processing:

```python
# Add custom post-processing
def post_process_content(content, config):
    # Add custom headers, footers, or transformations
    return enhanced_content
```

### Multiple Model Comparison

Create multiple configs with different models:

```json
// prompts/comparison_sonnet.json
{
  "template": "article.txt",
  "output_name": "article_sonnet",
  "model_id": "anthropic.claude-3-sonnet-20240229-v1:0"
}

// prompts/comparison_haiku.json
{
  "template": "article.txt",
  "output_name": "article_haiku",
  "model_id": "anthropic.claude-3-haiku-20240307-v1:0"
}
```

### Scheduled Generation

Add a scheduled workflow:

```yaml
# .github/workflows/scheduled.yml
on:
  schedule:
    - cron: '0 9 * * 1'  # Every Monday at 9 AM UTC
```

## Examples

See the `prompts/` directory for complete examples:

- `welcome_prompt.json` - Welcome email generation
- `summary_prompt.json` - Module summary generation

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add your prompt configurations
4. Test locally
5. Submit a Pull Request

## License

MIT License - see LICENSE file for details

## Support

For issues or questions:
- Open a GitHub issue
- Check workflow logs in Actions tab
- Review CloudWatch logs for Bedrock invocations

## Resources

- [Amazon Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)
- [Boto3 Bedrock Runtime Documentation](https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/bedrock-runtime.html)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [S3 Static Website Hosting](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteHosting.html)
