terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
  }
}

data "coder_parameter" "dotfiles_uri" {
  type         = "string"
  name         = "dotfiles_uri"
  display_name = "Dotfiles URL"
  order        = var.coder_parameter_order
  description  = var.description
  mutable      = true
  icon         = "/icon/dotfiles.svg"
}

data "coder_parameter" "dotfiles_mode" {
  name        = "Dotfiles Mode"
  description = "How should embedded dotfiles be applied?"
  type        = "string"
  default     = "none"
  mutable     = true
  icon        = "/icon/dotfiles.svg"
  option {
    name  = "Symlink"
    value = "symlink"
  }
  option {
    name  = "Copy"
    value = "copy"
  }
  option {
    name  = "None"
    value = "none"
  }
}

data "coder_parameter" "dotfiles_packages" {
  count       = data.coder_parameter.dotfiles_mode.value == "symlink" ? 1 : 0
  name        = "Dotfiles Packages"
  description = "Space-separated list of package specifiers for stow/manual linking"
  icon        = "/icon/dotfiles.svg"
  type        = "string"
  default     = ""
  mutable     = true
}

locals {
  dotfiles_uri = data.coder_parameter.dotfiles_uri.value
  user         = var.user != null ? var.user : ""

  resolved_mode = data.coder_parameter.dotfiles_mode.value

  resolved_packages = try(data.coder_parameter.dotfiles_packages[0].value, "")
}

resource "coder_script" "link_dotfiles" {
  agent_id           = var.agent_id
  display_name       = "Link Dotfiles"
  icon               = "/icon/dotfiles.svg"
  run_on_start       = true
  start_blocks_login = false
  script = templatefile("${path.module}/run.sh", {
    DOTFILES_URI   = local.dotfiles_uri,
    MODE           = local.resolved_mode,
    PACKAGES       = local.resolved_packages,
    PRESERVE_STASH = tostring(var.stow_preserve_changes),
    DOTFILES_USER  = local.user
  })
}

output "dotfiles_uri" {
  description = "Dotfiles URI"
  value       = local.dotfiles_uri
}

output "mode" {
  description = "Resolved mode for applying dotfiles"
  value       = local.resolved_mode
}

output "packages" {
  description = "Resolved PACKAGES value used by the module"
  value       = local.resolved_packages
}

output "stow_preserve_changes" {
  description = "Whether the module will stash repo changes after stow adoption"
  value       = var.stow_preserve_changes
}
