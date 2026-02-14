variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "beta_bucket_name" {
  description = "Name of the S3 bucket for beta environment (must be globally unique)"
  type        = string
  default     = "prompt-deploy-pipeline-beta"
}

variable "prod_bucket_name" {
  description = "Name of the S3 bucket for production environment (must be globally unique)"
  type        = string
  default     = "prompt-deploy-pipeline-prod"
}

variable "enable_public_access" {
  description = "Enable public access to buckets for static website hosting"
  type        = bool
  default     = false
}

variable "enable_website_hosting" {
  description = "Enable static website hosting on S3 buckets"
  type        = bool
  default     = true
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "PromptDeploymentPipeline"
}

variable "cost_center" {
  description = "Cost center for billing tracking"
  type        = string
  default     = "Engineering"
}

variable "owner_email" {
  description = "Owner email for resource tracking"
  type        = string
  default     = ""
}

variable "compliance_tags" {
  description = "Compliance framework tags (e.g., SOC2, HIPAA, PCI-DSS)"
  type        = string
  default     = "SOC2"
}

variable "alert_email" {
  description = "Email address for CloudWatch alerts"
  type        = string
  default     = "jen4rill@live.com"
  sensitive   = true
}

variable "enable_aws_config" {
  description = "Enable AWS Config for compliance monitoring"
  type        = bool
  default     = false
}

variable "enable_cost_alerts" {
  description = "Enable AWS Budgets cost alerts"
  type        = bool
  default     = true
}

variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD"
  type        = number
  default     = 50
}

variable "enable_cross_region_replication" {
  description = "Enable S3 cross-region replication for disaster recovery"
  type        = bool
  default     = false
}

variable "replication_region" {
  description = "AWS region for cross-region replication"
  type        = string
  default     = "us-west-2"
}

variable "retention_days_beta" {
  description = "Number of days to retain beta outputs before deletion"
  type        = number
  default     = 30
}

variable "retention_days_prod" {
  description = "Number of days to retain prod outputs (0 = infinite)"
  type        = number
  default     = 0
}

variable "enable_cloudtrail" {
  description = "Enable CloudTrail for audit logging"
  type        = bool
  default     = true
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "enable_github_oidc" {
  description = "Enable GitHub OIDC for secure authentication (replaces long-lived credentials)"
  type        = bool
  default     = true
}

variable "github_repository" {
  description = "GitHub repository in format 'owner/repo' for OIDC trust"
  type        = string
  default     = ""
}

variable "enforce_account_public_access_block" {
  description = "Enforce S3 public access block at account level"
  type        = bool
  default     = true
}

variable "enable_guardduty" {
  description = "Enable AWS GuardDuty for threat detection"
  type        = bool
  default     = false
}

variable "enable_security_hub" {
  description = "Enable AWS Security Hub for compliance monitoring"
  type        = bool
  default     = false
}

variable "enable_mfa_delete" {
  description = "Enable MFA delete on S3 buckets (requires bucket owner MFA)"
  type        = bool
  default     = false
}

variable "enable_object_lock" {
  description = "Enable S3 Object Lock for compliance (prevents deletion)"
  type        = bool
  default     = false
}

variable "enable_glacier_archive" {
  description = "Enable AWS Glacier for long-term archival"
  type        = bool
  default     = false
}
