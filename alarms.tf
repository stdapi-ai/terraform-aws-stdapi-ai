/*
CloudWatch Log Metric Filters and Alarms
*/

locals {
  # Derived from the topic the alarms would notify. An explicit setting still wins, including
  # alarms_enabled = true with no topic: every alarm tolerates its absence, the four in the server
  # module as much as the log alarm below, and all five are then created with no action at all --
  # billed, and there to be read on the console.
  alarms_enabled = var.alarms_enabled != null ? var.alarms_enabled : var.sns_topic_arn != null
}

# Metric filter for ERROR and CRITICAL log levels
resource "aws_cloudwatch_log_metric_filter" "error_critical_logs" {
  for_each       = local.alarms_enabled ? toset(["enabled"]) : toset([])
  name           = "${local.name}-error-critical-logs"
  log_group_name = module.server.cloudwatch_log_groups_names["main"]
  pattern        = "?error ?ERROR ?critical ?CRITICAL"

  metric_transformation {
    name          = "${local.name}-ErrorCriticalCount"
    namespace     = "CustomMetrics/ECS"
    value         = "1"
    default_value = 0
  }
}

# Alarm for ERROR and CRITICAL logs
resource "aws_cloudwatch_metric_alarm" "error_critical_logs" {
  for_each            = local.alarms_enabled ? toset(["enabled"]) : toset([])
  alarm_name          = "${local.name}-error-critical-logs"
  tags                = local.tags
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "${local.name}-ErrorCriticalCount"
  namespace           = "CustomMetrics/ECS"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "This metric monitors ERROR and CRITICAL level logs in the application"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : null
  treat_missing_data  = "notBreaching"
}
