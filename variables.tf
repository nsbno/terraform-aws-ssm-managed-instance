variable "name_prefix" {
  description = "A prefix used for naming resources."
  type        = string
}

variable "instance_name" {
  description = "(Optional) A name to associate with the managed instance."
  type        = string
}

variable "instance_tags" {
  description = "(Optional) A set of tags (key-value pairs) to add to the managed instance."
  type        = map(string)
  default     = {}
}

variable "kms_arn" {
  description = "The ARN of a KMS key or alias to use when encrypting parameters in Parameter Store."
  type        = string
}

variable "policy_arns" {
  description = "A list of ARNs of policies to attach to the SSM service role."
  type        = list(string)
  default     = []
}

variable "policy_statements" {
  description = "A list of policy statements to attach to the SSM service role."
  default     = []
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = map(string)
  default     = {}
}
