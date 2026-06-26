data "aws_caller_identity" "current" {}

# ── KMS key for state encryption ─────────────────────────────────────────────
resource "aws_kms_key" "state" {
  description             = "KMS key for Terraform state — ${var.name_prefix}-${var.environment}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "Root"
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "kms:*"
      Resource  = "*"
    }]
  })
}

resource "aws_kms_alias" "state" {
  name          = "alias/${var.name_prefix}-${var.environment}-state"
  target_key_id = aws_kms_key.state.key_id
}

# ── S3 state bucket ───────────────────────────────────────────────────────────
resource "aws_s3_bucket" "state" {
  bucket = "${var.name_prefix}-${var.environment}-tfstate-${data.aws_caller_identity.current.account_id}"
  lifecycle { prevent_destroy = true }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.state.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "state" {
  bucket     = aws_s3_bucket.state.id
  depends_on = [aws_s3_bucket_public_access_block.state]
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyHTTP"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
}

# ── DynamoDB state lock ───────────────────────────────────────────────────────
resource "aws_dynamodb_table" "state_lock" {
  name         = "${var.name_prefix}-${var.environment}-tfstate-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute { name = "LockID"; type = "S" }
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.state.arn
  }
}

# ── GitHub Actions OIDC provider ──────────────────────────────────────────────
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}

# ── IAM Role: Plan — any ref, read-only ──────────────────────────────────────
resource "aws_iam_role" "plan" {
  name = "${var.name_prefix}-${var.environment}-ci-plan"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike   = { "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*" }
        StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
      }
    }]
  })
}

resource "aws_iam_role_policy" "plan" {
  name = "tf-plan"
  role = aws_iam_role.plan.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "StateRead"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket", "s3:GetBucketVersioning", "s3:GetEncryptionConfiguration"]
        Resource = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]
      },
      {
        Sid    = "LockRW"
        Effect = "Allow"
        Action = ["dynamodb:DescribeTable", "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
        Resource = aws_dynamodb_table.state_lock.arn
      },
      {
        Sid      = "KMSRead"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:DescribeKey", "kms:GenerateDataKey"]
        Resource = aws_kms_key.state.arn
      },
      {
        Sid    = "ReadOnly"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "eks:Describe*", "eks:List*",
          "iam:Get*", "iam:List*",
          "kms:Describe*", "kms:List*",
        ]
        Resource = "*"
      },
    ]
  })
}

# ── IAM Role: Apply — main branch only ───────────────────────────────────────
# NOTE: AdministratorAccess is acceptable for a sandbox learning environment.
# Scope this down to specific actions before using in staging/production.
resource "aws_iam_role" "apply" {
  name = "${var.name_prefix}-${var.environment}-ci-apply"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:ref:refs/heads/main"
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "apply_admin" {
  role       = aws_iam_role.apply.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
