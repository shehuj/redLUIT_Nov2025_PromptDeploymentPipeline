# Disaster Recovery - Cross-Region Replication

# Secondary Region Provider
provider "aws" {
  alias  = "replication"
  region = var.replication_region
}

# Replication IAM Role
resource "aws_iam_role" "replication" {
  count = var.enable_cross_region_replication ? 1 : 0
  name  = "${var.project_name}-s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "replication" {
  count = var.enable_cross_region_replication ? 1 : 0
  name  = "${var.project_name}-s3-replication-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.beta.arn,
          aws_s3_bucket.prod.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Resource = [
          "${aws_s3_bucket.beta.arn}/*",
          "${aws_s3_bucket.prod.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Resource = [
          "${aws_s3_bucket.prod_replica[0].arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = [
          aws_kms_key.beta.arn,
          aws_kms_key.prod.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt"
        ]
        Resource = [
          aws_kms_key.prod_replica[0].arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "replication" {
  count      = var.enable_cross_region_replication ? 1 : 0
  role       = aws_iam_role.replication[0].name
  policy_arn = aws_iam_policy.replication[0].arn
}

# KMS Key in Replication Region
resource "aws_kms_key" "prod_replica" {
  count                   = var.enable_cross_region_replication ? 1 : 0
  provider                = aws.replication
  description             = "KMS key for production S3 bucket replication"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name        = "${var.project_name}-Prod-Replica-KMS"
    Environment = "DR"
  }
}

resource "aws_kms_alias" "prod_replica" {
  count         = var.enable_cross_region_replication ? 1 : 0
  provider      = aws.replication
  name          = "alias/${var.project_name}-prod-replica"
  target_key_id = aws_kms_key.prod_replica[0].key_id
}

# Replica S3 Bucket for Production
resource "aws_s3_bucket" "prod_replica" {
  count    = var.enable_cross_region_replication ? 1 : 0
  provider = aws.replication
  bucket   = "${var.prod_bucket_name}-replica"

  tags = {
    Name        = "${var.project_name}-Prod-Replica"
    Environment = "DR"
    Replica     = "true"
  }
}

resource "aws_s3_bucket_versioning" "prod_replica" {
  count    = var.enable_cross_region_replication ? 1 : 0
  provider = aws.replication
  bucket   = aws_s3_bucket.prod_replica[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "prod_replica" {
  count    = var.enable_cross_region_replication ? 1 : 0
  provider = aws.replication
  bucket   = aws_s3_bucket.prod_replica[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.prod_replica[0].arn
    }
    bucket_key_enabled = true
  }
}

# Replication Configuration for Production Bucket
resource "aws_s3_bucket_replication_configuration" "prod" {
  count = var.enable_cross_region_replication ? 1 : 0
  # Must have bucket versioning enabled
  depends_on = [aws_s3_bucket_versioning.prod]

  role   = aws_iam_role.replication[0].arn
  bucket = aws_s3_bucket.prod.id

  rule {
    id     = "replicate-all"
    status = "Enabled"

    filter {
      prefix = "prod/"
    }

    destination {
      bucket        = aws_s3_bucket.prod_replica[0].arn
      storage_class = "STANDARD_IA"

      encryption_configuration {
        replica_kms_key_id = aws_kms_key.prod_replica[0].arn
      }

      metrics {
        status = "Enabled"
      }

      replication_time {
        status = "Enabled"
        time {
          minutes = 15
        }
      }
    }

    delete_marker_replication {
      status = "Enabled"
    }
  }
}

# Glacier Vault for Long-term Archive (optional)
resource "aws_glacier_vault" "archive" {
  count = var.enable_glacier_archive ? 1 : 0
  name  = "${var.project_name}-long-term-archive"

  tags = {
    Name        = "${var.project_name}-Glacier-Archive"
    Environment = "Archive"
  }
}

resource "aws_glacier_vault_lock" "archive" {
  count              = var.enable_glacier_archive ? 1 : 0
  vault_name         = aws_glacier_vault.archive[0].name
  complete_lock      = false
  ignore_deletion_error = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "deny-deletion"
        Effect = "Deny"
        Principal = {
          AWS = "*"
        }
        Action = [
          "glacier:DeleteArchive"
        ]
        Resource = aws_glacier_vault.archive[0].arn
        Condition = {
          NumericLessThan = {
            "glacier:ArchiveAgeInDays" = "365"
          }
        }
      }
    ]
  })
}
