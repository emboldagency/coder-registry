variable "agent_id" {
  description = "The coder agent id to attach the script to"
  type        = string
}

variable "timezone" {
  description = "Timezone string to set inside the workspace (e.g. America/New_York). If empty, the script is a no-op."
  type        = string
  default     = null # If unset (null), the module will use the workspace parameter value instead.
}

variable "parameter_order" {
  type        = number
  description = "The order determines the position of a template parameter in the UI/CLI presentation."
  default     = null
}
