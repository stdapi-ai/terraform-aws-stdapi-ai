/*
CloudWatch Log Metric Filters and Alarms
*/

# Metric filter for ERROR and CRITICAL log levels
resource "aws_cloudwatch_log_metric_filter" "error_critical_logs" {
  for_each       = var.alarms_enabled ? toset(["enabled"]) : toset([])
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
  for_each            = var.alarms_enabled ? toset(["enabled"]) : toset([])
  alarm_name          = "${local.name}-error-critical-logs"
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
