# Resource Cleanup Guide

This guide explains how to safely clean up and delete AWS resources created by the Prompt Deployment Pipeline.

## 🎯 Quick Start

### Option 1: GitHub Actions Workflow (Recommended)

1. Go to **Actions** tab in GitHub
2. Select **"Cleanup Resources"** workflow
3. Click **"Run workflow"**
4. Choose options:
   - **Environment**: beta, prod, or all
   - **Delete S3 buckets**: Yes/No
   - **Destroy infrastructure**: Yes/No
   - **Confirmation**: Type `DESTROY`
5. Click **"Run workflow"**

### Option 2: Local Script

```bash
# Run the interactive cleanup script
./scripts/cleanup.sh

# Follow the menu to choose cleanup option
```

### Option 3: Manual Terraform Destroy

```bash
cd terraform
terraform destroy
```

---

## 📋 Cleanup Options Explained

### 1. **Beta Environment Only**
Deletes:
- Beta S3 bucket and all contents
- Beta KMS key alias
- Beta-specific resources

**Cost impact**: Eliminates ~50% of costs

```bash
./scripts/cleanup.sh
# Choose option 1
```

### 2. **Prod Environment Only**
Deletes:
- Prod S3 bucket and all contents
- Prod KMS key alias
- Prod-specific resources

**Cost impact**: Eliminates ~50% of costs

```bash
./scripts/cleanup.sh
# Choose option 2
```

### 3. **Complete Cleanup (All Resources)**
Deletes:
- All S3 buckets (beta, prod, access logs)
- All KMS keys
- CloudWatch logs, alarms, dashboards
- SNS topics
- All Terraform-managed infrastructure

**Cost impact**: Eliminates 100% of costs

```bash
./scripts/cleanup.sh
# Choose option 3
```

### 4. **Empty S3 Buckets Only**
Deletes:
- All objects in S3 buckets
- All object versions

**Keeps**:
- Bucket infrastructure
- KMS keys
- CloudWatch resources

**Use case**: Free up storage costs while keeping infrastructure

```bash
./scripts/cleanup.sh
# Choose option 4
```

### 5. **Terraform Destroy Only**
Uses Terraform to destroy infrastructure while preserving S3 contents.

**Keeps**: S3 bucket contents (if buckets exist outside Terraform)

```bash
cd terraform
terraform destroy
```

### 6. **Custom Cleanup**
Interactive selection of specific resources to delete.

```bash
./scripts/cleanup.sh
# Choose option 6
```

---

## 💰 Cost Impact by Resource

Understanding what costs money helps decide what to clean up:

### High Cost Resources
| Resource | Typical Monthly Cost | Cleanup Impact |
|----------|---------------------|----------------|
| **S3 Storage** | $0.023/GB | Immediate savings |
| **Bedrock API Calls** | $0.024/request | Future savings |
| **S3 Requests** | $0.005/1K requests | Minimal |

### Low/Free Resources
| Resource | Cost | Notes |
|----------|------|-------|
| **KMS Keys** | $1/month each | Only active keys |
| **CloudWatch Logs** | $0.50/GB ingested | Storage only |
| **CloudWatch Alarms** | $0.10/alarm | Low volume |
| **SNS Topics** | Free | No cost |

---

## 📝 Cleanup Checklist

### Before Cleanup

- [ ] **Backup important data**
  ```bash
  aws s3 sync s3://your-bucket ./backup/
  ```

- [ ] **Document current state**
  ```bash
  aws s3 ls > bucket-list.txt
  terraform state pull > terraform-state-backup.json
  ```

- [ ] **Verify you have the right AWS account**
  ```bash
  aws sts get-caller-identity
  ```

### After Cleanup

- [ ] **Verify resources deleted**
  ```bash
  aws s3 ls | grep prompt
  aws kms list-aliases | grep PromptDeploymentPipeline
  ```

- [ ] **Check AWS billing** (wait 24-48 hours)

---

## ⚠️ Important Warnings

### KMS Key Deletion

**Important**: KMS keys have a mandatory **30-day waiting period** before deletion.

### Versioned S3 Buckets

S3 buckets with versioning enabled require deleting all versions first. The cleanup script handles this automatically.

---

## 📞 Need Help?

- **GitHub Issues**: Report problems or ask questions
- **Makefile**: Run `make help` for quick commands

---

**Remember**: Deleted resources cannot be recovered. Always backup important data first!
