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
  plugin_content = file("${path.module}/adminer-auto-login.php")
}

// Removed docker_volume: plugin files are ephemeral and recreated on each container start.

resource "docker_image" "adminer" {
  name          = data.docker_registry_image.adminer.name
  pull_triggers = [data.docker_registry_image.adminer.sha256_digest]
  keep_locally  = true
}

resource "docker_container" "adminer" {
  count        = data.coder_workspace.me.start_count
  name         = "${var.resource_name_base}-adminer"
  image        = docker_image.adminer.name
  hostname     = "adminer"
  network_mode = var.docker_network_name
  must_run     = true
  # Run as default image user (adminer) for least privilege; we'll prepare plugins via entrypoint
  user = "adminer"
  env = [
    "ADMINER_DEFAULT_SERVER=${var.db_server}",
    "ADMINER_DEFAULT_USERNAME=${var.db_username}",
    "ADMINER_DEFAULT_PASSWORD=${var.db_password}",
    "ADMINER_DEFAULT_DB=${var.db_name}",
    "ADMINER_DEFAULT_DRIVER=${var.db_driver}",
    "ADMINER_DESIGN=${var.adminer_design}",
  ]

  # Populate plugin files and clean stale stubs before starting server.
  entrypoint = ["sh", "-c", <<-EOT
    set -eu
    PLUG_DIR=/var/www/html/plugins-enabled
    mkdir -p $PLUG_DIR
    # Write plugin from file content
    cat > $PLUG_DIR/auto-login.php <<'EOF'
${local.plugin_content}
EOF
    chmod 0644 $PLUG_DIR/auto-login.php
    # Start original server
    exec entrypoint.sh docker-php-entrypoint php -S [::]:8080 -t /var/www/html
  EOT
  ]

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

data "docker_registry_image" "adminer" {
  name = "adminer:latest"
}

resource "coder_app" "adminer" {
  count        = data.coder_workspace.me.start_count
  agent_id     = var.agent_id
  slug         = "adminer"
  display_name = "Adminer"
  url          = "http://localhost:18080"
  share        = "authenticated"
  subdomain    = true
  icon         = "https://api.embold.net/icons/?name=adminer.svg"
  order        = 3

  healthcheck {
    url       = "http://localhost:18080"
    interval  = 5
    threshold = 6
  }
}


resource "coder_script" "adminer_reverse_proxy" {
  agent_id           = var.agent_id
  script             = templatefile("${path.module}/run.sh", { PROXY_LINE = join(" ", var.proxy_mappings) })
  display_name       = "Reverse Proxy"
  icon               = "https://api.embold.net/icons/?name=socat.svg"
  run_on_start       = true
  start_blocks_login = true
}
