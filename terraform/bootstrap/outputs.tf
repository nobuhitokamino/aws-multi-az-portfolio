output "state_bucket_name" {
  description = "Terraform State保存用S3バケット名"
  value       = aws_s3_bucket.terraform_state.bucket
}
