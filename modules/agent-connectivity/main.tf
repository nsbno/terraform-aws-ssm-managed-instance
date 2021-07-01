data "aws_caller_identity" "this" {}
data "aws_region" "this" {}

locals {
  current_account_id = data.aws_caller_identity.this.account_id
  current_region     = data.aws_region.this.name
  metric_namespace   = coalesce(var.metric_namespace, "${var.name_prefix}-agent-connectivity")
  metric_names = {
    ssm_agent_disconnected = "SSMAgentDisconnected"
    ecs_agent_disconnected = "ECSAgentDisconnected"
  }
}

data "archive_file" "this" {
  type        = "zip"
  source_file = "${path.module}/src/main.py"
  output_path = "${path.module}/.terraform_artifacts/package.zip"
}

resource "aws_lambda_function" "this" {
  function_name    = "${var.name_prefix}-agent-connectivity"
  role             = aws_iam_role.this.arn
  handler          = "main.lambda_handler"
  runtime          = "python3.8"
  timeout          = var.lambda_timeout
  filename         = data.archive_file.this.output_path
  source_code_hash = data.archive_file.this.output_base64sha256
  environment {
    variables = {
      DRY_RUN          = var.lambda_dry_run
      METRIC_NAMESPACE = local.metric_namespace
      METRIC_NAMES     = jsonencode(local.metric_names)
    }
  }
  tags = var.tags
}

resource "aws_iam_role" "this" {
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "logs_to_lambda" {
  policy = data.aws_iam_policy_document.logs_for_lambda.json
  role   = aws_iam_role.this.id
}

resource "aws_iam_role_policy" "metrics_to_lambda" {
  policy = data.aws_iam_policy_document.metrics_for_lambda.json
  role   = aws_iam_role.this.id
}

resource "aws_iam_role_policy" "ssm_to_lambda" {
  policy = data.aws_iam_policy_document.ssm_for_lambda.json
  role   = aws_iam_role.this.id
}

resource "aws_iam_role_policy" "ecs_to_lambda" {
  policy = data.aws_iam_policy_document.ecs_for_lambda.json
  role   = aws_iam_role.this.id
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${aws_lambda_function.this.function_name}"
  retention_in_days = 14
  tags              = var.tags
}
