provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

# ============================================================
# KMS KEY
# ============================================================

resource "aws_kms_key" "s3_key" {
  description             = "KMS key for DevOps S3 buckets"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAndUserPermissions"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
            data.aws_caller_identity.current.arn
          ]
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}

# ============================================================
# MAIN S3 BUCKET
# ============================================================

resource "aws_s3_bucket" "devops_bucket" {
  bucket = "devops-python-app-demo-bucket-2026"

  #checkov:skip=CKV2_AWS_62:Event notifications are not required for this development environment.
  #checkov:skip=CKV_AWS_144:Cross-region replication is not required for this development environment.

  lifecycle {
    ignore_changes = []
  }
}

# Public access block
resource "aws_s3_bucket_public_access_block" "devops_bucket" {
  bucket = aws_s3_bucket.devops_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning
resource "aws_s3_bucket_versioning" "devops_bucket" {
  bucket = aws_s3_bucket.devops_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# KMS encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "devops_bucket" {
  bucket = aws_s3_bucket.devops_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_key.arn
      sse_algorithm     = "aws:kms"
    }

    bucket_key_enabled = true
  }
}

# ============================================================
# LOGGING BUCKET
# ============================================================

resource "aws_s3_bucket" "logs_bucket" {
  bucket = "devops-python-app-logs-2026"

  #checkov:skip=CKV2_AWS_62:Event notifications are not required for this logging bucket.
  #checkov:skip=CKV_AWS_144:Cross-region replication is not required for this development environment.

  lifecycle {
    ignore_changes = []
  }
}

# Public access block
resource "aws_s3_bucket_public_access_block" "logs_bucket" {
  bucket = aws_s3_bucket.logs_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning
resource "aws_s3_bucket_versioning" "logs_bucket" {
  bucket = aws_s3_bucket.logs_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# KMS encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "logs_bucket" {
  bucket = aws_s3_bucket.logs_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_key.arn
      sse_algorithm     = "aws:kms"
    }

    bucket_key_enabled = true
  }
}

# ============================================================
# S3 ACCESS LOGGING
# ============================================================

resource "aws_s3_bucket_logging" "devops_bucket" {
  bucket = aws_s3_bucket.devops_bucket.id

  target_bucket = aws_s3_bucket.logs_bucket.id
  target_prefix = "log/"
}

# ============================================================
# MAIN BUCKET LIFECYCLE
# ============================================================

resource "aws_s3_bucket_lifecycle_configuration" "devops_bucket" {
  bucket = aws_s3_bucket.devops_bucket.id

  rule {
    id     = "cleanup-old-objects"
    status = "Enabled"

    expiration {
      days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# ============================================================
# LOGGING BUCKET LIFECYCLE
# ============================================================

resource "aws_s3_bucket_lifecycle_configuration" "logs_bucket" {
  bucket = aws_s3_bucket.logs_bucket.id

  rule {
    id     = "cleanup-old-logs"
    status = "Enabled"

    expiration {
      days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
