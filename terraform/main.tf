terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state backend (uncomment and configure after initial deployment)
  # backend "s3" {
  #   # Values are set via backend config file or CLI
  #   # terraform init -backend-config="backend-config.tfvars"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Environment = "MultiEnv"
      CostCenter  = var.cost_center
      Owner       = var.owner_email
    }
  }
}

# KMS Keys for Encryption
resource "aws_kms_key" "beta" {
  description             = "KMS key for beta S3 bucket encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name        = "${var.project_name}-Beta-KMS"
    Environment = "Beta"
  }
}

resource "aws_kms_alias" "beta" {
  name          = "alias/${var.project_name}-beta"
  target_key_id = aws_kms_key.beta.key_id
}

resource "aws_kms_key" "prod" {
  description             = "KMS key for production S3 bucket encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name        = "${var.project_name}-Prod-KMS"
    Environment = "Production"
  }
}

resource "aws_kms_alias" "prod" {
  name          = "alias/${var.project_name}-prod"
  target_key_id = aws_kms_key.prod.key_id
}

# CloudWatch Log Group for S3 Access Logs
resource "aws_cloudwatch_log_group" "s3_access_logs" {
  name              = "/aws/s3/${var.project_name}"
  retention_in_days = 90

  tags = {
    Name = "${var.project_name}-S3-Access-Logs"
  }
}

# S3 Bucket for Access Logs
resource "aws_s3_bucket" "access_logs" {
  bucket = "${var.beta_bucket_name}-access-logs"

  tags = {
    Name        = "${var.project_name}-Access-Logs"
    Environment = "Logging"
  }
}

# Configure bucket ownership for access logs
resource "aws_s3_bucket_ownership_controls" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "access_logs" {
  depends_on = [aws_s3_bucket_ownership_controls.access_logs]
  bucket     = aws_s3_bucket.access_logs.id
  acl        = "log-delivery-write"
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    id     = "delete-old-logs"
    status = "Enabled"

    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}

# S3 Bucket for Beta Environment
resource "aws_s3_bucket" "beta" {
  bucket = var.beta_bucket_name

  tags = {
    Name        = "Prompt-DeploymentPipeline-Beta"
    Environment = "Beta"
    DataClass   = "Internal"
  }
}

# Enable S3 access logging for beta bucket
resource "aws_s3_bucket_logging" "beta" {
  bucket = aws_s3_bucket.beta.id

  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "beta-bucket-logs/"
}

resource "aws_s3_bucket_versioning" "beta" {
  bucket = aws_s3_bucket.beta.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "beta" {
  bucket = aws_s3_bucket.beta.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.beta.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "beta" {
  bucket = aws_s3_bucket.beta.id

  rule {
    id     = "delete-old-beta-outputs"
    status = "Enabled"

    filter {
      prefix = "beta/outputs/"
    }

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

# S3 Bucket for Production Environment
resource "aws_s3_bucket" "prod" {
  bucket = var.prod_bucket_name

  tags = {
    Name        = "Prompt-Deployment-Pipeline-Production"
    Environment = "Production"
    DataClass   = "Confidential"
    Compliance  = var.compliance_tags
  }
}

# Enable S3 access logging for prod bucket
resource "aws_s3_bucket_logging" "prod" {
  bucket = aws_s3_bucket.prod.id

  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "prod-bucket-logs/"
}

resource "aws_s3_bucket_versioning" "prod" {
  bucket = aws_s3_bucket.prod.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "prod" {
  bucket = aws_s3_bucket.prod.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.prod.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "prod" {
  bucket = aws_s3_bucket.prod.id

  rule {
    id     = "archive-old-prod-outputs"
    status = "Enabled"

    filter {
      prefix = "prod/outputs/"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# Optional: Public access for static website hosting
resource "aws_s3_bucket_public_access_block" "beta" {
  bucket = aws_s3_bucket.beta.id

  block_public_acls       = var.enable_public_access ? false : true
  block_public_policy     = var.enable_public_access ? false : true
  ignore_public_acls      = var.enable_public_access ? false : true
  restrict_public_buckets = var.enable_public_access ? false : true
}

resource "aws_s3_bucket_public_access_block" "prod" {
  bucket = aws_s3_bucket.prod.id

  block_public_acls       = var.enable_public_access ? false : true
  block_public_policy     = var.enable_public_access ? false : true
  ignore_public_acls      = var.enable_public_access ? false : true
  restrict_public_buckets = var.enable_public_access ? false : true
}

# Optional: Bucket policy for public read access
resource "aws_s3_bucket_policy" "prod" {
  count  = var.enable_public_access ? 1 : 0
  bucket = aws_s3_bucket.prod.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.prod.arn}/prod/outputs/*"
      }
    ]
  })
}

# Optional: Static website hosting
resource "aws_s3_bucket_website_configuration" "prod" {
  count  = var.enable_website_hosting ? 1 : 0
  bucket = aws_s3_bucket.prod.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_website_configuration" "beta" {
  count  = var.enable_website_hosting ? 1 : 0
  bucket = aws_s3_bucket.beta.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# CORS configuration for web access
resource "aws_s3_bucket_cors_configuration" "beta" {
  count  = var.enable_public_access ? 1 : 0
  bucket = aws_s3_bucket.beta.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_cors_configuration" "prod" {
  count  = var.enable_public_access ? 1 : 0
  bucket = aws_s3_bucket.prod.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}
