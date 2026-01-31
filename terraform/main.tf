terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# S3 Bucket for Beta Environment
resource "aws_s3_bucket" "beta" {
  bucket = var.beta_bucket_name

  tags = {
    Name        = "Prompt-DeploymentPipeline-Beta"
    Environment = "Beta"
    ManagedBy   = "Terraform"
    Project     = "PromptDeploymentPipeline"
  }
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
      sse_algorithm = "AES256"
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
    ManagedBy   = "Terraform"
    Project     = "PromptDeploymentPipeline"
  }
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
      sse_algorithm = "AES256"
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
