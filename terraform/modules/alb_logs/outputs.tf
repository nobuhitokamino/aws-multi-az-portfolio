output "bucket_name" {
  description = "ALBアクセスログ保存用S3バケット名"
  value       = aws_s3_bucket.logs.id

  # バケットポリシーの設定完了後に利用可能にする
  depends_on = [
    aws_s3_bucket_policy.logs,
    aws_s3_bucket_lifecycle_configuration.logs
  ]
}
