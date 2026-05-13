# Hourly metric + alarm when Cognito app clients (e.g. dev-hub API keys) reach the service quota danger zone.

locals {
  cognito_app_client_count_monitor_enabled = var.enable_cognito_app_client_count_monitor
  cognito_app_client_metric_namespace      = "TradeTariff/Identity"
  cognito_app_client_metric_name           = "AppClientCount"
  cognito_app_client_alarm_threshold       = 800
}

data "aws_sns_topic" "cognito_app_client_alarm" {
  count = local.cognito_app_client_count_monitor_enabled ? 1 : 0
  name  = "slack-topic"
}

data "archive_file" "cognito_app_client_count_lambda_zip" {
  count = local.cognito_app_client_count_monitor_enabled ? 1 : 0

  type        = "zip"
  source_file = "${path.module}/lambda/cognito_app_client_count/app_client_count.py"
  output_path = "${path.module}/lambda/cognito_app_client_count/tmp/app_client_count.zip"
}

resource "aws_iam_role" "cognito_app_client_count" {
  count = local.cognito_app_client_count_monitor_enabled ? 1 : 0

  name = "trade-tariff-identity-app-client-count-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

data "aws_iam_policy_document" "cognito_app_client_count_lambda" {
  count = local.cognito_app_client_count_monitor_enabled ? 1 : 0

  statement {
    sid = "Logging"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:${data.aws_region.current.name}:${local.account_id}:*"]
  }

  statement {
    sid       = "ListUserPoolClients"
    actions   = ["cognito-idp:ListUserPoolClients"]
    resources = [data.aws_cognito_user_pool.this.arn]
  }

  statement {
    sid    = "PutMetricData"
    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricData",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = [local.cognito_app_client_metric_namespace]
    }
  }
}

resource "aws_iam_role_policy" "cognito_app_client_count" {
  count = local.cognito_app_client_count_monitor_enabled ? 1 : 0

  name   = "trade-tariff-identity-app-client-count-${var.environment}"
  role   = aws_iam_role.cognito_app_client_count[0].id
  policy = data.aws_iam_policy_document.cognito_app_client_count_lambda[0].json
}

resource "aws_cloudwatch_log_group" "cognito_app_client_count" {
  count = local.cognito_app_client_count_monitor_enabled ? 1 : 0

  name              = "/aws/lambda/trade-tariff-identity-cognito-app-client-count-${var.environment}"
  retention_in_days = 14
}

resource "aws_lambda_function" "cognito_app_client_count" {
  count = local.cognito_app_client_count_monitor_enabled ? 1 : 0

  function_name = "trade-tariff-identity-cognito-app-client-count-${var.environment}"
  role          = aws_iam_role.cognito_app_client_count[0].arn
  handler       = "app_client_count.lambda_handler"
  runtime       = "python3.11"
  timeout       = 60

  filename         = data.archive_file.cognito_app_client_count_lambda_zip[0].output_path
  source_code_hash = data.archive_file.cognito_app_client_count_lambda_zip[0].output_base64sha256

  environment {
    variables = {
      USER_POOL_ID     = data.aws_cognito_user_pool.this.id
      ENVIRONMENT      = var.environment
      METRIC_NAMESPACE = local.cognito_app_client_metric_namespace
      METRIC_NAME      = local.cognito_app_client_metric_name
    }
  }

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.cognito_app_client_count[0].name
  }

  depends_on = [aws_cloudwatch_log_group.cognito_app_client_count]
}

resource "aws_cloudwatch_event_rule" "cognito_app_client_count" {
  count = local.cognito_app_client_count_monitor_enabled ? 1 : 0

  name                = "trade-tariff-identity-app-client-count-${var.environment}"
  description         = "Publish Cognito identity pool app client count custom metric"
  schedule_expression = "rate(1 hour)"
}

resource "aws_cloudwatch_event_target" "cognito_app_client_count" {
  count = local.cognito_app_client_count_monitor_enabled ? 1 : 0

  rule      = aws_cloudwatch_event_rule.cognito_app_client_count[0].name
  target_id = "trade-tariff-identity-app-client-count-${var.environment}"
  arn       = aws_lambda_function.cognito_app_client_count[0].arn
}

resource "aws_lambda_permission" "cognito_app_client_count_events" {
  count = local.cognito_app_client_count_monitor_enabled ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cognito_app_client_count[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cognito_app_client_count[0].arn
}

resource "aws_cloudwatch_metric_alarm" "cognito_app_client_count" {
  count = local.cognito_app_client_count_monitor_enabled ? 1 : 0

  alarm_name          = "trade-tariff-identity-cognito-app-client-count-${var.environment}"
  alarm_description   = "Identity Cognito user pool app clients >= ${local.cognito_app_client_alarm_threshold}. Mitigate via Service Quota increase and/or cleanup of stale credentials clients."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = local.cognito_app_client_metric_name
  namespace           = local.cognito_app_client_metric_namespace
  period              = 3600
  statistic           = "Maximum"
  threshold           = local.cognito_app_client_alarm_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    UserPoolId  = data.aws_cognito_user_pool.this.id
    Environment = var.environment
  }

  alarm_actions = [data.aws_sns_topic.cognito_app_client_alarm[0].arn]
  ok_actions    = [data.aws_sns_topic.cognito_app_client_alarm[0].arn]
}
