variable "agent_id" {
  description = "The coder agent id to attach the script to"
  type        = string
}

variable "dotfiles_uri" {
  description = "Optional override for the dotfiles URI. When set, the module skips creating a coder_parameter and uses this value directly. Useful for backward-compatible upgrades where the URI comes from a legacy parameter."
  type        = string
  default     = null
}

variable "default_dotfiles_uri" {
  description = "Default value for the dotfiles_uri parameter (when the parameter is created by the module)."
  type        = string
  default     = ""
}

variable "parameter_order" {
  type        = number
  description = "The order determines the position of a template parameter in the UI/CLI presentation. The lowest order is shown first and parameters with equal order are sorted by name (ascending order)."
  default     = null
}



variable "description" {
  type        = string
  description = "A custom description for the dotfiles parameter. This is shown in the UI - and allows you to customize the instructions you give to your users."
  default     = "Enter a URL for a [dotfiles repository](https://dotfiles.github.io) to personalize your workspace"
}



variable "group" {
  type        = string
  description = "The name of a group that this app belongs to."
  default     = null
}



variable "order" {
  type        = number
  description = "The order determines the position of app in the UI presentation. The lowest order is shown first and apps with equal order are sorted by name (ascending order)."
  default     = null
}



variable "stow_preserve_changes" {
  description = "When true, stash working-tree changes after running 'stow --adopt' to preserve local edits. Set to false to skip creating a stash."
  type        = bool
  default     = true
}

variable "user" {
  type        = string
  description = "The name of the user to apply the dotfiles to. (optional, applies to the current user by default)"
  default     = null
}
