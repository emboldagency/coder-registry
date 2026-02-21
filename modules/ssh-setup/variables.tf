variable "agent_id" {
  description = "The coder agent id to attach the script to"
  type        = string
}

variable "hosts" {
  description = "List of host:port entries to ensure in known_hosts"
  type        = list(string)
  default     = []
}
