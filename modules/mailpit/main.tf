terraform {
  required_version = ">= 1.0"
  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 2.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 3.0"
    }
  }
}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

locals {
  user_id        = try(data.coder_workspace_owner.me.id, "unknown")
  user_username  = try(data.coder_workspace_owner.me.name, "unknown")
  workspace_id   = try(data.coder_workspace_owner.me.id, "unknown")
  workspace_name = try(data.coder_workspace.me.name, "unknown")
}

variable "order" {
  description = "Order for Coder parameters in this module. This module can create a maximum of 34 parameters, so choose an order that leaves room for your other parameters."
  type        = number
  default     = 0
}

resource "docker_volume" "mailpit_volume" {
  count = data.coder_workspace.me.start_count
  name  = "${var.resource_name_base}-mailpit"
  lifecycle {
    ignore_changes = all
  }
  # Add labels in Docker to keep track of orphan resources.
  labels {
    label = "coder.owner"
    value = local.user_username
  }
  labels {
    label = "coder.owner_id"
    value = local.user_id
  }
  labels {
    label = "coder.workspace_id"
    value = local.workspace_id
  }
  # This field becomes outdated if the workspace is renamed but can
  # be useful for debugging or cleaning out dangling volumes.
  labels {
    label = "coder.workspace_name_at_creation"
    value = local.workspace_name
  }
}

resource "docker_image" "mailpit" {
  name          = data.docker_registry_image.mailpit.name
  pull_triggers = [data.docker_registry_image.mailpit.sha256_digest]
  keep_locally  = true
}

resource "docker_container" "mailpit" {
  count        = data.coder_workspace.me.start_count
  name         = "${var.resource_name_base}-mailpit"
  image        = docker_image.mailpit.name
  hostname     = "mailpit"
  network_mode = var.docker_network_name
  env = [
    "MP_API_PORT=8026",
    "MP_DATABASE=/data/mailpit.db",
    "MP_MAX_AGE=30d",
    "MP_MAX_MESSAGES=5000",
    "MP_SMTP_BIND_ADDR=0.0.0.0:1025",
    "MP_UI_BIND_ADDR=0.0.0.0:8025",
  ]

  volumes {
    container_path = "/data"
    volume_name    = docker_volume.mailpit_volume[count.index].name
    read_only      = false
  }

  labels {
    label = "coder.owner"
    value = local.user_username
  }

  labels {
    label = "coder.owner_id"
    value = local.user_id
  }

  labels {
    label = "coder.workspace_id"
    value = local.workspace_id
  }
}

data "docker_registry_image" "mailpit" {
  name = "axllent/mailpit:latest"
}

resource "coder_app" "mailpit" {
  count        = data.coder_workspace.me.start_count
  agent_id     = var.agent_id
  slug         = "mailpit"
  display_name = "Mailpit"
  url          = "http://localhost:18025"
  share        = "authenticated"
  subdomain    = true
  icon         = "https://api.embold.net/icons/?name=mailpit.svg"
  order        = 3

  healthcheck {
    url       = "http://localhost:18025"
    interval  = 5
    threshold = 6
  }
}

resource "coder_script" "mailpit_reverse_proxy" {
  agent_id           = var.agent_id
  script             = templatefile("${path.module}/run.sh", { PROXY_LINE = join(" ", var.proxy_mappings) })
  display_name       = "Reverse Proxy"
  icon               = "https://api.embold.net/icons/?name=socat.svg"
  run_on_start       = true
  start_blocks_login = true
}
