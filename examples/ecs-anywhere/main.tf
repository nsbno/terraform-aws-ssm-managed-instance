terraform {
  required_providers {
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

resource "aws_kms_key" "this" {
  description = "Key used for encrypting SSM activation ID and code in Parameter Store."
  tags        = local.tags
}


#####################################################
#
# SSM activation
#
#####################################################
module "managed_instance" {
  source      = "../../"
  name_prefix = "${local.name_prefix}-${local.instance_name}"
  kms_arn     = aws_kms_key.this.arn
  policy_arns = [
    # Managed policy required by the ECS agent
    "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
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
