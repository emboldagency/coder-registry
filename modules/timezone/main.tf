terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
  }
}

data "coder_parameter" "timezone" {
  count       = var.timezone == null ? 1 : 0
  name        = "Timezone"
  description = "Set the container timezone for the workspace."
  icon        = "https://api.embold.net/icons/?name=fas-clock.svg&color=009dff"
  type        = "string"
  default     = "America/New_York"
  mutable     = true
  order       = var.parameter_order
  option {
    name  = "UTC"
    value = "UTC"
  }
  option {
    name  = "America/New_York (Eastern)"
    value = "America/New_York"
  }
  option {
    name  = "America/Los_Angeles (Pacific)"
    value = "America/Los_Angeles"
  }
}

resource "coder_script" "timezone" {
  agent_id = var.agent_id
  # Use the caller-provided var.timezone when non-empty, otherwise fall back
  # to the workspace parameter value defined here. Render the chosen value
  # into the script via templatefile. If var.timezone is null, create a dynamic
  # workspace parameter so end-users can change it at runtime.
  script             = templatefile("${path.module}/run.sh", { TIMEZONE = local.resolved_timezone })
  display_name       = "Timezone"
  icon               = "https://api.embold.net/icons/?name=fas-clock.svg&color=009dff"
  run_on_start       = true
  start_blocks_login = false
}
locals {
  # Resolve the timezone in one place with consistent types.
  # Precedence: explicit var.timezone -> dynamic parameter (if present) -> data parameter -> empty string
  resolved_timezone = coalesce(
    var.timezone,
    try(data.coder_parameter.timezone[0].value, ""),
    ""
  )
}

output "timezone" {
  description = "The resolved timezone value (either caller-provided or workspace parameter)."
  value       = local.resolved_timezone
}
