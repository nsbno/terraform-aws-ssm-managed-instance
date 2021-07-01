output "log_group_arn" {
  description = "The ARN of the CloudWatch log group used by the default CloudWatch agent configuration."
  value       = aws_cloudwatch_log_group.this.arn
}

output "log_group_name" {
  description = "The name of the CloudWatch log group used by the default CloudWatch agent configuration."
  value       = aws_cloudwatch_log_group.this.name
}

output "metric_namespace" {
  description = "The name of the CloudWatch metric namespace used by the default CloudWatch agent configuration."
  value       = local.metric_namespace
}

output "ssm_parameter_name" {
  description = "The name of the SSM parameter containing the configuration for the CloudWatch agent."
  value       = aws_ssm_parameter.agent_config.name
}

output "ssm_parameter_arn" {
  description = "The ARN of the SSM parameter containing the configuration for the CloudWatch agent."
  value       = aws_ssm_parameter.agent_config.arn
}
