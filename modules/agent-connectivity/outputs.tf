output "function_name" {
  value = aws_lambda_function.this.function_name
}

output "function_arn" {
  value = aws_lambda_function.this.arn
}

output "metric_namespace" {
  value = local.metric_namespace
}

output "metric_names" {
  value = local.metric_names
}
