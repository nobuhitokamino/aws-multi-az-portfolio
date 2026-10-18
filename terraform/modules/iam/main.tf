# EC2がIAM Roleを引き受けるための信頼ポリシー
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type = "Service"

      identifiers = [
        "ec2.amazonaws.com"
      ]
    }
  }
}

# EC2用IAM Role
resource "aws_iam_role" "ec2" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name      = "${var.project_name}-ec2-role"
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}

# EC2用Instance Profile
resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-ec2-profile"

  role = aws_iam_role.ec2.name

  tags = {
    Name      = "${var.project_name}-ec2-profile"
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}
