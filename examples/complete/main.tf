terraform {
  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.2.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.44.0"
    }
  }
  required_version = ">= 1.0.0"
}

provider "aws" {
  region = "eu-west-1"
}

locals {
  name_prefix   = "example"
  instance_name = "my-example-server"
  tags = {
    terraform = true
    project   = local.name_prefix
  }
}


#####################################################
#
# Automatically install and configure the CloudWatch
# agent on the SSM-managed instance
#
#####################################################
module "cloudwatch_agent" {
  source              = "../../modules/cloudwatch-agent"
  name_prefix         = "${local.name_prefix}-${local.instance_name}"
  instance_identifier = "${local.name_prefix}-${local.instance_name}"
  instance_targets = [
    {
      key    = "tag:instance-name"
      values = ["${local.name_prefix}-${local.instance_name}"]
    }
  ]
  tags = local.tags
}


#####################################################
#
# SSM activation
#
#####################################################
resource "aws_kms_key" "this" {
  description = "Key used for encrypting SSM activation ID and code in Parameter Store."
  tags        = local.tags
}

module "managed_instance" {
  source      = "../../"
  name_prefix = "${local.name_prefix}-${local.instance_name}"
  kms_arn     = aws_kms_key.this.arn
  policy_arns = [
    # Managed policy required by the ECS agent
    "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
  ]
  policy_statements = [
    # Policies required by the CloudWatch agent
    {
      effect    = "Allow"
      actions   = ["ssm:GetParameter"],
      resources = [module.cloudwatch_agent.ssm_parameter_arn]
    },
    {
      effect    = "Allow"
      actions   = ["logs:CreateLogStream", "logs:PutLogEvents"],
      resources = ["${module.cloudwatch_agent.log_group_arn}:*"]
    },
    {
      effect    = "Allow"
      actions   = ["cloudwatch:PutMetricData"],
      resources = ["*"]
      condition = [{
        test     = "StringEquals"
        variable = "cloudwatch:namespace"
        values   = [module.cloudwatch_agent.metric_namespace]
      }]
    }
  ]
  tags = local.tags
}


#####################################################
#
# ECS resources 
#
#####################################################
resource "aws_ecs_cluster" "this" {
  name = "${local.name_prefix}-external"
  tags = local.tags
}

module "container" {
  source               = "github.com/nsbno/terraform-aws-ecs-anywhere?ref=ec7622c"
  name_prefix          = "${local.name_prefix}-nginx"
  cluster_arn          = aws_ecs_cluster.this.arn
  task_container_image = "nginx@sha256:d96a932a263f003339751442aa14073fbab77032ca3f2e5f7e42c9f10ec275f5"
  task_container_health_check = {
    command     = ["CMD-SHELL", "curl -f http://localhost:80 || exit 1"]
    interval    = 30
    retries     = 3
    startPeriod = 3
    timeout     = 10
  }
  task_memory = 256
}


#####################################################
#
# Monitor connection to SSM and ECS agent
#
#####################################################
module "agent_connectivity" {
  source      = "../../modules/agent-connectivity"
  name_prefix = local.name_prefix
  tags        = local.tags
}

resource "aws_lambda_permission" "this" {
  action        = "lambda:InvokeFunction"
  function_name = module.agent_connectivity.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.this.arn
}

resource "aws_cloudwatch_event_rule" "this" {
  description         = "Periodically monitor the connection status of SSM and ECS agents running on managed instances."
  schedule_expression = "rate(1 minute)"
  tags                = local.tags
}

resource "aws_cloudwatch_event_target" "agent" {
  arn = module.agent_connectivity.function_arn
  input = jsonencode({
    ecs_cluster = aws_ecs_cluster.this.name
  })
  rule = aws_cloudwatch_event_rule.this.name
}

resource "aws_cloudwatch_metric_alarm" "ssm_agent" {
  alarm_name        = "${module.managed_instance.instance_name}-ssm-agent"
  alarm_description = "Triggers if AWS has lost connection to the SSM agent on an instance named '${module.managed_instance.instance_name}' (e.g., due to network outage, instance downtime, etc.)"
  namespace         = module.agent_connectivity.metric_namespace
  metric_name       = module.agent_connectivity.metric_names.ssm_agent_disconnected
  dimensions = {
    InstanceName = module.managed_instance.instance_name
  }
  statistic                 = "SampleCount"
  period                    = 60
  alarm_actions             = []
  insufficient_data_actions = []
  ok_actions                = []
  comparison_operator       = "GreaterThanThreshold"
  treat_missing_data        = "notBreaching"
  threshold                 = 0
  evaluation_periods        = 1
  datapoints_to_alarm       = 1
  tags                      = local.tags
}

resource "aws_cloudwatch_metric_alarm" "ecs_agent" {
  alarm_name        = "${module.managed_instance.instance_name}-ecs-agent"
  alarm_description = "Triggers if AWS has lost connection to the ECS agent on an instance named '${module.managed_instance.instance_name}' (e.g., due to network outage, instance downtime, etc.)"
  namespace         = module.agent_connectivity.metric_namespace
  metric_name       = module.agent_connectivity.metric_names.ecs_agent_disconnected
  dimensions = {
    InstanceName = module.managed_instance.instance_name
  }
  statistic                 = "SampleCount"
  period                    = 60
  alarm_actions             = []
  insufficient_data_actions = []
  ok_actions                = []
  comparison_operator       = "GreaterThanThreshold"
  treat_missing_data        = "notBreaching"
  threshold                 = 0
  evaluation_periods        = 1
  datapoints_to_alarm       = 1
  tags                      = local.tags
}
