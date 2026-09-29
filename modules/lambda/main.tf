data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/builds/${var.function_name}.zip"
}

resource "aws_lambda_function" "lambda" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = var.function_name
  role             = var.role_arn
  handler          = var.handler
  runtime          = var.runtime
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = var.timeout
  memory_size      = var.memory_size

  dynamic "environment" {
    for_each = length(keys(var.environment_variables)) > 0 ? [1] : []
    content {
      variables = var.environment_variables
    }
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "lambda_log" {
  name              = "/aws/lambda/${aws_lambda_function.lambda.function_name}"
  retention_in_days = 7
}

# EventBridge Trigger (Cron)
resource "aws_cloudwatch_event_rule" "cron" {
  count               = var.schedule_expression != "" ? 1 : 0
  name                = "${var.function_name}-trigger"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  count = var.schedule_expression != "" ? 1 : 0
  rule  = aws_cloudwatch_event_rule.cron[0].name
  arn   = aws_lambda_function.lambda.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  count         = var.schedule_expression != "" ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cron[0].arn
}
