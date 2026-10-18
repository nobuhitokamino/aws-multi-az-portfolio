# AWSアカウント情報を取得
data "aws_caller_identity" "current" {}

# Terraform State保存用S3バケット
resource "aws_s3_bucket" "terraform_state" {
  bucket = "aws-multi-az-portfolio-state-${data.aws_caller_identity.current.account_id}-apne1"

  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name      = "aws-multi-az-portfolio-state"
    Project   = "aws-multi-az-portfolio"
    ManagedBy = "Terraform"
  }
}

# バージョニングを有効化
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# サーバー側暗号化
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# パブリックアクセスをすべてブロック
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
