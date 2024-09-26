data "aws_region" "this" {}

locals {
  current_region = data.aws_region.this.name
}

resource "aws_iam_role" "this" {
  name               = "${var.name_prefix}-ssm-managed-instance-${var.instance_name}"
  description        = "Role used by SSM-managed instances named '${var.instance_name}'"
  assume_role_policy = data.aws_iam_policy_document.ssm_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "additional" {
  for_each   = toset(var.policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "additional" {
  count  = length(var.policy_statements) > 0 ? 1 : 0
  role   = aws_iam_role.this.name
  policy = data.aws_iam_policy_document.additional[0].json
}

resource "aws_ssm_activation" "this" {
  name               = var.instance_name
  iam_role           = aws_iam_role.this.id
  registration_limit = 1
  tags = merge({
    instance-name = var.instance_name
  }, var.tags, var.instance_tags)
  depends_on = [aws_iam_role_policy_attachment.this]
}

resource "aws_ssm_parameter" "ssm_activation_id" {
  name   = "/${var.name_prefix}/managed-instance/${var.instance_name}/ssm-activation-id"
  type   = "SecureString"
  value  = aws_ssm_activation.this.id
  key_id = var.kms_arn
  tags   = var.tags
}

resource "aws_ssm_parameter" "ssm_activation_code" {
  name   = "/${var.name_prefix}/managed-instance/${var.instance_name}/ssm-activation-code"
  type   = "SecureString"
  value  = aws_ssm_activation.this.activation_code
  key_id = var.kms_arn
  tags   = var.tags
}
