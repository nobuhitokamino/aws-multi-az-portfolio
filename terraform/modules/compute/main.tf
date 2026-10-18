# CloudWatch Agentの設定を生成
locals {
  agent_config = jsonencode({
    agent = {
      region      = var.aws_region
      run_as_user = "root"
    }

    logs = {
      logs_collected = {
        files = {
          collect_list = [
            {
              file_path       = "/var/log/nginx/access.log"
              log_group_name  = var.log_group_name
              log_stream_name = "{instance_id}/access"
            },
            {
              file_path       = "/var/log/nginx/error.log"
              log_group_name  = var.log_group_name
              log_stream_name = "{instance_id}/error"
            }
          ]
        }
      }
    }
  })
}

# EC2 Launch Template
resource "aws_launch_template" "web" {
  name = "${var.project_name}-web-lt"

  image_id      = var.ami_id
  instance_type = var.instance_type

  vpc_security_group_ids = [
    var.ec2_sg_id
  ]

  iam_instance_profile {
    name = var.instance_profile_name
  }

  # IMDSv2を必須にする
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  # EBSルートボリューム
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 10
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  # UserData
  user_data = base64encode(templatefile(
    "${path.module}/../../templates/user_data.sh.tftpl",
    {
      nginx_config = file(
        "${path.module}/../../../config/nginx.conf"
      )

      index_html = file(
        "${path.module}/../../../userdata/index.html"
      )

      agent_config = local.agent_config
    }
  ))

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name      = "${var.project_name}-web"
      Project   = var.project_name
      ManagedBy = "Terraform"
    }
  }

  tags = {
    Name      = "${var.project_name}-web-lt"
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}
