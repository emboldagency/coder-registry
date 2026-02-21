variable "agent_id" {
  description = "The coder agent id to attach the script to"
  type        = string
}

variable "proxy_mappings" {
  description = "List of proxy mappings in the form local_port:remote_host:remote_port"
  type        = list(string)
  default     = []
}
