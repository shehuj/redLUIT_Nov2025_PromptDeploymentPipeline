# GitHub Actions Workflows

## Available Workflows

### 1. Deploy Infrastructure (deploy.yml)
- **Trigger**: Manual
- **Purpose**: Deploy Terraform infrastructure to AWS
- **Usage**: Actions → Deploy Infrastructure → Run workflow

### 2. Cleanup Infrastructure (cleanup.yml)
- **Trigger**: Manual with confirmation
- **Purpose**: Destroy all infrastructure  
- **Usage**: Actions → Cleanup Infrastructure → Type DESTROY → Run

### 3. CI - Test & Validate (ci.yml)
- **Trigger**: Automatic on PR/push
- **Purpose**: Run tests and security scans
- **Usage**: Runs automatically

## Quick Start

1. Configure GitHub secret: `AWS_ACCOUNT_ID=615299732970`
2. Run deploy workflow to create infrastructure
3. Run cleanup workflow when done (type DESTROY)

See main documentation for detailed instructions.
