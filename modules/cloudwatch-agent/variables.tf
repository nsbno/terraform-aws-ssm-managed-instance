variable "name_prefix" {
  description = "A prefix used for naming resources."
  type        = string
}

variable "custom_agent_config" {
  description = "A custom JSON configuration to use for the CloudWatch agent instead of the default one."
  default     = ""
  type        = string
}

variable "instance_targets" {
  description = "A list of targets of the SSM association."
  type = list(object({
    key    = string
    values = list(string)
  }))
}

variable "log_group_name" {
  description = "(Optional) The name of the log group to create and use for logs collected by the CloudWatch agent when using the default JSON configuration."
  default     = ""
}

variable "instance_identifier" {
  description = "An identifier to use for metric dimensions and log stream names for metrics and logs collected by the CloudWatch agent when using the default JSON configuration. (NOTE: A hardcoded value like `my-instance-name` can be used here if the module is being used to target only a single managed instance.)"
}

variable "metric_namespace" {
  description = "(Optional) Name of a custom metric namespace to use for metrics collected by the CloudWatch agent when using the default JSON configuration."
  default     = ""
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = map(string)
  default     = {}
}
