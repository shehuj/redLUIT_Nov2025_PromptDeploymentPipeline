# CloudWatch Monitoring and Alarms for Enterprise Production

# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  name              = "${var.project_name}-alerts"
  display_name      = "Prompt Deployment Pipeline Alerts"
  kms_master_key_id = aws_kms_key.prod.id

  tags = {
    Name        = "${var.project_name}-Alerts"
    Environment = "Production"
  }
}

resource "aws_sns_topic_subscription" "alert_email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# CloudWatch Log Metric Filters for Error Detection
resource "aws_cloudwatch_log_metric_filter" "s3_errors" {
  name           = "${var.project_name}-s3-errors"
  log_group_name = aws_cloudwatch_log_group.s3_access_logs.name
  pattern        = "[... , status_code=4*, ...]"

  metric_transformation {
    name      = "S3ErrorCount"
    namespace = var.project_name
    value     = "1"
  }
}

# CloudWatch Alarms

# Alarm for S3 4xx Errors
resource "aws_cloudwatch_metric_alarm" "s3_4xx_errors" {
  alarm_name          = "${var.project_name}-s3-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "4xxErrors"
  namespace           = "AWS/S3"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Alert when S3 4xx errors exceed threshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    BucketName = aws_s3_bucket.prod.id
  }

  tags = {
    Name        = "${var.project_name}-S3-4xx-Alarm"
    Environment = "Production"
  }
}

# Alarm for S3 5xx Errors
resource "aws_cloudwatch_metric_alarm" "s3_5xx_errors" {
  alarm_name          = "${var.project_name}-s3-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5xxErrors"
  namespace           = "AWS/S3"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Alert when S3 5xx errors exceed threshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    BucketName = aws_s3_bucket.prod.id
  }

  tags = {
    Name        = "${var.project_name}-S3-5xx-Alarm"
    Environment = "Production"
  }
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/S3", "BucketSizeBytes", { stat = "Average", label = "Beta Bucket Size" }],
            [".", ".", { stat = "Average", label = "Prod Bucket Size" }]
          ]
          period = 86400
          stat   = "Average"
          region = var.aws_region
          title  = "S3 Bucket Sizes"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/S3", "NumberOfObjects", { stat = "Average", label = "Beta Objects" }],
            [".", ".", { stat = "Average", label = "Prod Objects" }]
          ]
          period = 86400
          stat   = "Average"
          region = var.aws_region
          title  = "S3 Object Counts"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/S3", "4xxErrors", { stat = "Sum", label = "4xx Errors" }],
            [".", "5xxErrors", { stat = "Sum", label = "5xx Errors" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "S3 Errors"
        }
      }
    ]
  })
}

# AWS Config for Compliance Monitoring (if enabled)
resource "aws_config_configuration_recorder" "main" {
  count    = var.enable_aws_config ? 1 : 0
  name     = "${var.project_name}-config-recorder"
  role_arn = aws_iam_role.config_role[0].arn

  recording_group {
    all_supported = true
    include_global_resource_types = true
  }
}

resource "aws_iam_role" "config_role" {
  count = var.enable_aws_config ? 1 : 0
  name  = "${var.project_name}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "config_policy" {
  count      = var.enable_aws_config ? 1 : 0
  role       = aws_iam_role.config_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/ConfigRole"
}

# Cost Budget Alert
resource "aws_budgets_budget" "monthly_cost" {
  count         = var.enable_cost_alerts ? 1 : 0
  name          = "${var.project_name}-monthly-budget"
  budget_type   = "COST"
  limit_amount  = var.monthly_budget_limit
  limit_unit    = "USD"
  time_unit     = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_email != "" ? [var.alert_email] : []
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_email != "" ? [var.alert_email] : []
  }
}
