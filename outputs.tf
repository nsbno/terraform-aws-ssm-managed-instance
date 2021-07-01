output "activation_id_ssm_parameter_arn" {
  value = aws_ssm_parameter.ssm_activation_id.arn
}

output "activation_code_ssm_parameter_arn" {
  value = aws_ssm_parameter.ssm_activation_code.arn
}

output "activation_id_ssm_parameter_name" {
  value = aws_ssm_parameter.ssm_activation_id.name
}

output "activation_code_ssm_parameter_name" {
  value = aws_ssm_parameter.ssm_activation_code.name
}

output "instance_name" {
  value = local.instance_name
}

output "role_name" {
  value = aws_iam_role.this.name
}
