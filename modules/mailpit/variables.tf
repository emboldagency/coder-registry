variable "agent_id" {
  description = "The coder agent id to attach the script to"
  type        = string
}

variable "docker_network_name" {
  type        = string
  description = "The name of the Docker network to attach containers to."
  default     = "bridge"
}

variable "resource_name_base" {
  type        = string
  description = "A unique prefix for all created Docker resources (e.g., 'coder-user-workspace-id')."
}

variable "container_memory_limit" {
  type        = number
  description = "Memory limit for each dynamic container in MB."
  default     = 512

  validation {
    condition     = var.container_memory_limit >= 64 && var.container_memory_limit <= 4096
    error_message = "Container memory limit must be between 64MB and 4096MB."
  }
}

variable "container_user_id" {
  type        = string
  description = "User ID to run containers as. Leave null to use container default."
  default     = null
}

variable "proxy_mappings" {
  description = "List of proxy mappings in the form local_port:remote_host:remote_port"
  type        = list(string)
  default     = ["18025:mailpit:8025"]
}
