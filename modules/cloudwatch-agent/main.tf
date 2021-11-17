data "aws_caller_identity" "this" {}
data "aws_region" "this" {}

locals {
  current_account_id = data.aws_caller_identity.this.account_id
  current_region     = data.aws_region.this.name
  metric_namespace   = coalesce(var.metric_namespace, "${var.name_prefix}-${var.instance_identifier}-cloudwatch-agent")
  log_group_name     = coalesce(var.log_group_name, "${var.name_prefix}-${var.instance_identifier}-cloudwatch-agent")
}

resource "aws_ssm_document" "this" {
  name            = "${var.name_prefix}-${var.instance_identifier}-cloudwatch-agent"
  document_type   = "Command"
  document_format = "YAML"
  target_type     = "/"
  content = templatefile("${path.module}/document.yml", {
    AWS_REGION         = local.current_region
    SSM_PARAMETER_NAME = aws_ssm_parameter.agent_config.name
  })
  tags = var.tags
}

resource "aws_ssm_association" "this" {
  name             = aws_ssm_document.this.name
  association_name = "${var.name_prefix}-${var.instance_identifier}-cloudwatch-agent"
  dynamic "targets" {
    for_each = var.instance_targets
    content {
      key    = targets.value.key
      values = targets.value.values
    }
  }
}

resource "aws_cloudwatch_log_group" "this" {
  name              = local.log_group_name
  retention_in_days = 14
  tags              = var.tags
}

resource "aws_ssm_parameter" "agent_config" {
  name = "/${var.name_prefix}/managed-instance/${var.instance_identifier}/cloudwatch-agent-config"
  type = "String"
  # Create minified JSON
  value = var.custom_agent_config != "" ? var.custom_agent_config : jsonencode(jsondecode(templatefile("${path.module}/default-agent-config.json", {
    LOG_GROUP_NAME      = aws_cloudwatch_log_group.this.name
    INSTANCE_IDENTIFIER = var.instance_identifier
    AWS_REGION          = local.current_region
    METRIC_NAMESPACE    = local.metric_namespace
  })))
  tags = var.tags
}
