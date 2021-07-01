data "aws_iam_policy_document" "logs_for_lambda" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "${aws_cloudwatch_log_group.this.arn}:*",
    ]
  }
}

data "aws_iam_policy_document" "metrics_for_lambda" {
  statement {
    effect    = "Allow"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = [local.metric_namespace]
    }
  }
}

data "aws_iam_policy_document" "ssm_for_lambda" {
  statement {
    effect    = "Allow"
    actions   = ["ssm:DescribeInstanceInformation"]
    resources = ["arn:aws:ssm:${local.current_region}:${local.current_account_id}:*"]
  }
}

data "aws_iam_policy_document" "ecs_for_lambda" {
  statement {
    effect    = "Allow"
    actions   = ["ecs:ListContainerInstances"]
    resources = ["arn:aws:ecs:${local.current_region}:${local.current_account_id}:cluster/*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["ecs:DescribeContainerInstances"]
    resources = ["arn:aws:ecs:${local.current_region}:${local.current_account_id}:container-instance/*"]
  }
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }
  }
}
