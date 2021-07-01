variable "name_prefix" {
  description = "A prefix used for naming resources."
  type        = string
}

variable "metric_namespace" {
  description = "The CloudWatch metric namespace to use when publishing metrics."
  default     = ""
  type        = string
}

variable "lambda_dry_run" {
  description = "Whether to run the Lambda function in dry-run (i.e., read-only) mode."
  default     = false
}

variable "lambda_timeout" {
  description = "The maximum number of seconds the Lambda is allowed to run."
  default     = 15
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = map(string)
  default     = {}
}
