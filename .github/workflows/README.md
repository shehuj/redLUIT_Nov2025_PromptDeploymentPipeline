# GitHub Actions Workflows

This directory contains automated CI/CD workflows for the Prompt Deployment Pipeline.

---

## 📋 Available Workflows

### 1. 🚀 Deploy Infrastructure (`deploy.yml`)

**Purpose**: Deploy Terraform infrastructure to AWS

**Trigger**: Manual (workflow_dispatch)

**How to Use**:
1. Go to GitHub Actions tab
2. Select "Deploy Infrastructure"
3. Click "Run workflow"
4. Select environment (dev/beta/prod)
5. Click "Run workflow" button

**What it does**:
- ✅ Checks out code
- ✅ Configures AWS credentials using OIDC
- ✅ Initializes Terraform
- ✅ Validates configuration
- ✅ Creates execution plan
- ✅ Applies infrastructure changes
- ✅ Outputs deployment information

**Requirements**:
- GitHub Secret: `AWS_ACCOUNT_ID` (set to: `615299732970`)
- IAM Role: `PromptDeploymentPipeline-github-actions-role` (already created)

---

### 2. 🗑️ Cleanup Infrastructure (`cleanup.yml`)

**Purpose**: Destroy all Terraform-managed infrastructure

**Trigger**: Manual (workflow_dispatch) with confirmation

**How to Use**:
1. Go to GitHub Actions tab
2. Select "Cleanup Infrastructure"
3. Click "Run workflow"
4. Type `DESTROY` in the confirmation field (exact match required)
5. Click "Run workflow" button

**What it does**:
- ⚠️ Validates confirmation input
- 🗑️ Empties all S3 buckets
- 💣 Runs `terraform destroy`
- ✅ Removes all infrastructure

**Safety Features**:
- Requires exact "DESTROY" confirmation
- Manual trigger only (no automatic cleanup)
- Empties S3 buckets before destroying (prevents errors)

**WARNING**: This action is IRREVERSIBLE!

---

### 3. 🔍 CI - Test & Validate (`ci.yml`)

**Purpose**: Automated testing and validation

**Trigger**:
- Pull requests to main branch
- Pushes to main branch

**What it does**:

#### Terraform Validation Job
- ✅ Terraform format check
- ✅ Terraform initialization
- ✅ Terraform validation

#### Python Linting Job
- ✅ Black code formatting check
- ✅ Flake8 linting

#### Python Testing Job
- ✅ Run unit tests
- ✅ Generate coverage report

#### Security Scanning Job
- ✅ Run Checkov security scan
- ✅ Check against documented exceptions

**Runs automatically** on every push and PR!

---

## 🔧 Setup Instructions

### 1. Configure GitHub Secrets

Go to: **Settings → Secrets and variables → Actions**

Add these secrets:
| Secret Name | Value | Description |
|------------|-------|-------------|
| `AWS_ACCOUNT_ID` | `615299732970` | Your AWS account ID |

**Note**: The IAM role `PromptDeploymentPipeline-github-actions-role` is already created by Terraform.

---

### 2. Verify OIDC Configuration

The Terraform code already creates the OIDC provider and IAM role. Verify it exists:

```bash
# Check OIDC provider
aws iam list-open-id-connect-providers

# Check IAM role
aws iam get-role --role-name PromptDeploymentPipeline-github-actions-role
```

---

## 📊 Workflow Status Badges

Add these to your README.md:

```markdown
![Deploy](https://github.com/YOUR_ORG/YOUR_REPO/actions/workflows/deploy.yml/badge.svg)
![CI](https://github.com/YOUR_ORG/YOUR_REPO/actions/workflows/ci.yml/badge.svg)
```

---

## 🎯 Common Scenarios

### Scenario 1: Deploy New Changes

```
1. Make changes to Terraform code
2. Create pull request
3. CI workflow runs automatically
4. Review and merge PR
5. Go to Actions → Deploy Infrastructure → Run workflow
6. Select environment
7. Monitor deployment
```

### Scenario 2: Test Changes Locally First

```bash
# Run locally before pushing
make tf-init
make tf-validate
make tf-plan

# If looks good, push and let CI validate
git push

# Then deploy via GitHub Actions
```

### Scenario 3: Cleanup Everything

```
1. Go to Actions → Cleanup Infrastructure
2. Type DESTROY in confirmation
3. Run workflow
4. Wait for completion (~5-10 minutes)
5. Verify with: make verify-cleanup
```

### Scenario 4: Rebuild from Scratch

```
1. Run cleanup workflow (type DESTROY)
2. Wait for completion
3. Run deploy workflow
4. Select environment
5. Infrastructure recreated
```

---

## 🔒 Security Features

### 1. OIDC Authentication
- ✅ No long-lived AWS credentials
- ✅ Temporary credentials per workflow run
- ✅ Automatic rotation
- ✅ Scoped to specific repository

### 2. Least Privilege IAM
- ✅ IAM role limited to required permissions only
- ✅ No admin access
- ✅ Scoped to specific resources

### 3. Manual Approvals
- ✅ Deploy workflow requires manual trigger
- ✅ Cleanup requires "DESTROY" confirmation
- ✅ No automatic destructive actions

### 4. Audit Trail
- ✅ All workflow runs logged
- ✅ CloudTrail records all AWS API calls
- ✅ GitHub Actions audit log

---

## 📈 Monitoring Workflow Runs

### View Workflow History
1. Go to "Actions" tab
2. Select a workflow from the left sidebar
3. View all runs with status

### View Run Details
1. Click on a specific run
2. View jobs and steps
3. Check logs for each step
4. Download artifacts if available

### Debugging Failed Runs
1. Click failed run
2. Expand failed job
3. Review error message
4. Check logs for details
5. Fix issue and re-run

---

## 🚨 Troubleshooting

### Problem: "Role not found" error

**Solution**:
```bash
# Verify role exists
aws iam get-role --role-name PromptDeploymentPipeline-github-actions-role

# If not exists, apply Terraform
terraform apply
```

### Problem: "Bucket not empty" during cleanup

**Solution**: The cleanup workflow already handles this by emptying buckets first. If it still fails:
```bash
# Manually empty buckets
make cleanup-all-buckets

# Then re-run cleanup workflow
```

### Problem: "Confirmation not valid"

**Solution**: You must type exactly `DESTROY` (all caps, no spaces)

### Problem: CI workflow fails on format check

**Solution**:
```bash
# Run formatter locally
make format

# Commit and push
git add .
git commit -m "Fix formatting"
git push
```

---

## 📚 Related Documentation

- [Terraform Documentation](../terraform/README.md)
- [Security Documentation](../SECURITY.md)
- [Cleanup Guide](../CLEANUP_GUIDE.md)
- [Deployment Success](../DEPLOYMENT_SUCCESS.md)

---

## 🎓 Best Practices

### 1. Always Run CI First
- Let CI validate changes before deploying
- Fix any issues before manual deployment
- Use CI as a safety gate

### 2. Deploy to Beta First
- Test in beta environment
- Verify functionality
- Then deploy to prod

### 3. Monitor After Deployment
- Check CloudWatch dashboards
- Review CloudTrail logs
- Verify all resources created

### 4. Document Changes
- Update CHANGELOG.md
- Document any breaking changes
- Update version tags

### 5. Backup Before Cleanup
- Export Terraform state
- Backup S3 data
- Document current configuration

---

## 📞 Support

### Getting Help
- Check workflow logs first
- Review documentation
- Check GitHub Issues

### Common Questions

**Q: How do I add a new environment?**
A: Add to the `options` list in deploy.yml workflow

**Q: Can I deploy to multiple environments at once?**
A: No, deploy to one environment at a time

**Q: How long does deployment take?**
A: ~5-10 minutes depending on changes

**Q: Can I cancel a running workflow?**
A: Yes, click the "Cancel workflow" button

**Q: What if deployment fails midway?**
A: Terraform will show errors. Fix and re-run. State is preserved.

---

**Workflows ready to use!** 🚀
