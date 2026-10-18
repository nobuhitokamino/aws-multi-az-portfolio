resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name        = "${var.project_name}-alb-5xx"
  alarm_description = "ALB 5XX error detected"

  namespace   = "AWS/ApplicationELB"
  metric_name = "HTTPCode_ELB_5XX_Count"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"

  treat_missing_data = "notBreaching"

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  depends_on = [aws_sns_topic_policy.alarms]
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_host" {
  alarm_name        = "${var.project_name}-alb-unhealthy-host"
  alarm_description = "Unhealthy target detected"

  namespace   = "AWS/ApplicationELB"
  metric_name = "UnHealthyHostCount"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }

  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"

  treat_missing_data = "notBreaching"

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  depends_on = [aws_sns_topic_policy.alarms]
}

resource "aws_cloudwatch_metric_alarm" "ec2_high_cpu" {
  alarm_name        = "${var.project_name}-ec2-high-cpu"
  alarm_description = "High average EC2 CPU utilization in ASG"

  namespace   = "AWS/EC2"
  metric_name = "CPUUtilization"

  dimensions = {
    AutoScalingGroupName = var.asg_name
  }

  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanOrEqualToThreshold"

  treat_missing_data = "missing"

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  depends_on = [aws_sns_topic_policy.alarms]
}
