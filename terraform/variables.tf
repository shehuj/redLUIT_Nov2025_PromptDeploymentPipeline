variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "beta_bucket_name" {
  description = "Name of the S3 bucket for beta environment (must be globally unique)"
  type        = string
}

variable "prod_bucket_name" {
  description = "Name of the S3 bucket for production environment (must be globally unique)"
  type        = string
}

variable "enable_public_access" {
  description = "Enable public access to buckets for static website hosting"
  type        = bool
  default     = false
}

variable "enable_website_hosting" {
  description = "Enable static website hosting on S3 buckets"
  type        = bool
  default     = false
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "PromptDeploymentPipeline"
}
