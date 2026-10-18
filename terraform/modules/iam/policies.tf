# SSM用AWS管理ポリシーをIAM Roleに関連付け
resource "aws_iam_role_policy_attachment" "ssm" {
  role = aws_iam_role.ec2.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# AWSアカウント情報を取得
data "aws_caller_identity" "current" {}

# CloudWatch Logs用ポリシー
data "aws_iam_policy_document" "nginx_logs" {

  statement {
    sid    = "WriteNginxLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents"
    ]

    resources = [
      "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:${var.log_group_name}:*"
    ]
  }

  statement {
    sid    = "DescribeLogGroups"
    effect = "Allow"

    actions = [
      "logs:DescribeLogGroups"
    ]

    resources = ["*"]
  }
}

# カスタムポリシーをEC2 Roleに付与
resource "aws_iam_role_policy" "nginx_logs" {
  name = "${var.project_name}-nginx-logs-policy"

  role   = aws_iam_role.ec2.id
  policy = data.aws_iam_policy_document.nginx_logs.json
}
