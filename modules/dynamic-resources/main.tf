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

variable "order" {
  description = "Order for Coder parameters in this module. This module can create a maximum of 34 parameters, so choose an order that leaves room for your other parameters."
  type        = number
  default     = 0
}

data "coder_workspace" "me" {}

locals {
  # Derive a simple sanitized workspace name: replace hyphens and spaces with underscores and lowercase.
  sanitized_workspace_name = (
    length(trimspace(try(data.coder_workspace.me.name, ""))) > 0
    ? lower(replace(replace(try(data.coder_workspace.me.name, ""), "-", "_"), " ", "_"))
    : "workspace"
  )

  # Get explicit volume names from parameter
  base_volume_names = try(jsondecode(data.coder_parameter.additional_volumes.value), [])

  # Build custom containers list (merging base parameters and filtering empties)
  custom_containers = [
    for i, c in [
      {
        name  = try(data.coder_parameter.container_1_name[0].value, "")
        image = try(data.coder_parameter.container_1_image[0].value, "")
        # Parse volume mounts from "volume:mount_path" string format.
        # Splits by colon, trims whitespace, and ignores malformed entries.
        mounts = { for m in try(jsondecode(data.coder_parameter.container_1_volume_mounts[0].value), []) : trimspace(split(":", m)[0]) => trimspace(split(":", m)[1]) if length(split(":", m)) >= 2 }
        # Parse environment variables from multiline string.
        # Splits by newline, trims whitespace, and ensures "KEY=VALUE" format via regex.
        env = [for l in split("\n", try(data.coder_parameter.container_1_env_vars[0].value, "")) : trimspace(l) if trimspace(l) != "" && can(regex("^[A-Za-z_][A-Za-z0-9_]*=.*$", trimspace(l)))]
      },
      {
        name   = try(data.coder_parameter.container_2_name[0].value, "")
        image  = try(data.coder_parameter.container_2_image[0].value, "")
        mounts = { for m in try(jsondecode(data.coder_parameter.container_2_volume_mounts[0].value), []) : trimspace(split(":", m)[0]) => trimspace(split(":", m)[1]) if length(split(":", m)) >= 2 }
        env    = [for l in split("\n", try(data.coder_parameter.container_2_env_vars[0].value, "")) : trimspace(l) if trimspace(l) != "" && can(regex("^[A-Za-z_][A-Za-z0-9_]*=.*$", trimspace(l)))]
      },
      {
        name   = try(data.coder_parameter.container_3_name[0].value, "")
        image  = try(data.coder_parameter.container_3_image[0].value, "")
        mounts = { for m in try(jsondecode(data.coder_parameter.container_3_volume_mounts[0].value), []) : trimspace(split(":", m)[0]) => trimspace(split(":", m)[1]) if length(split(":", m)) >= 2 }
        env    = [for l in split("\n", try(data.coder_parameter.container_3_env_vars[0].value, "")) : trimspace(l) if trimspace(l) != "" && can(regex("^[A-Za-z_][A-Za-z0-9_]*=.*$", trimspace(l)))]
      }
    ] : merge(c, { custom_index = i + 1 })
    if c.name != "" && c.image != ""
  ]

  # Identify implicit volumes from mounts (keys that don't look like paths).
  # Keys not starting with /, ., or ~ are treated as volume names to be created.
  implicit_volume_names = flatten([
    for c in local.custom_containers : keys({
      for k, v in c.mounts : k => v
      if !startswith(k, "/") && !startswith(k, ".") && !startswith(k, "~")
    })
  ])

  # Combine explicit and implicit volumes
  volume_names_to_create = distinct(concat(local.base_volume_names, local.implicit_volume_names))

  # Map for for_each resources
  all_containers_map = { for c in local.custom_containers : "custom-${c.custom_index}" => c }

  # Build apps from fixed parameter slots
  custom_apps = [
    for index, app in [
      {
        name         = try(data.coder_parameter.app_1_name[0].value, "")
        slug         = try(data.coder_parameter.app_1_slug[0].value, "")
        icon         = try(data.coder_parameter.app_1_icon[0].value, "")
        share        = try(data.coder_parameter.app_1_share[0].value, "owner")
        original_url = try(data.coder_parameter.app_1_url[0].value, "")
      },
      {
        name         = try(data.coder_parameter.app_2_name[0].value, "")
        slug         = try(data.coder_parameter.app_2_slug[0].value, "")
        icon         = try(data.coder_parameter.app_2_icon[0].value, "")
        share        = try(data.coder_parameter.app_2_share[0].value, "owner")
        original_url = try(data.coder_parameter.app_2_url[0].value, "")
      },
      {
        name         = try(data.coder_parameter.app_3_name[0].value, "")
        slug         = try(data.coder_parameter.app_3_slug[0].value, "")
        icon         = try(data.coder_parameter.app_3_icon[0].value, "")
        share        = try(data.coder_parameter.app_3_share[0].value, "owner")
        original_url = try(data.coder_parameter.app_3_url[0].value, "")
      }
      ] : {
      name         = app.name
      slug         = app.slug
      icon         = app.icon
      share        = app.share
      original_url = app.original_url
      # Parse URLs to extract host/port and calculate local mappings.
      # host: everything between http(s):// and the first colon or slash.
      # port: extracted from the URL, or defaults to 80/443 based on scheme.
      remote_host = try(regex("https?://([^:/]+)", app.original_url)[0], "")
      remote_port = try(tonumber(regex("https?://[^:/]+:(\\d+)", app.original_url)[0]), startswith(app.original_url, "https://") ? 443 : 80)
      local_port  = 19000 + try(tonumber(regex("https?://[^:/]+:(\\d+)", app.original_url)[0]), startswith(app.original_url, "https://") ? 443 : 80)
      proxy_url   = "http://localhost:${19000 + try(tonumber(regex("https?://[^:/]+:(\\d+)", app.original_url)[0]), startswith(app.original_url, "https://") ? 443 : 80)}"
    } if app.name != "" && app.slug != ""
  ]

  # Auto-generate apps from containers
  container_generated_apps = [
    for container in [
      {
        name       = try(data.coder_parameter.container_1_name[0].value, "")
        create_app = try(data.coder_parameter.container_1_create_coder_app[0].value, "false")
        port       = try(data.coder_parameter.container_1_ports[0].value, "")
        local_port = try(data.coder_parameter.container_1_local_port[0].value, "")
      },
      {
        name       = try(data.coder_parameter.container_2_name[0].value, "")
        create_app = try(data.coder_parameter.container_2_create_coder_app[0].value, "false")
        port       = try(data.coder_parameter.container_2_ports[0].value, "")
        local_port = try(data.coder_parameter.container_2_local_port[0].value, "")
      },
      {
        name       = try(data.coder_parameter.container_3_name[0].value, "")
        create_app = try(data.coder_parameter.container_3_create_coder_app[0].value, "false")
        port       = try(data.coder_parameter.container_3_ports[0].value, "")
        local_port = try(data.coder_parameter.container_3_local_port[0].value, "")
      }
      ] : {
      name         = container.name
      slug         = lower(replace(container.name, " ", "-"))
      icon         = local.icon.globe
      share        = "owner"
      original_url = "http://${container.name}:${container.port}"
      remote_host  = container.name
      remote_port  = tonumber(container.port)
      local_port   = tonumber(container.local_port)
      proxy_url    = "http://localhost:${container.local_port}"
    } if container.name != "" && container.create_app == "true" && container.port != "" && container.local_port != ""
  ]

  # Combine all apps for proxy generation
  additional_apps = concat(local.container_generated_apps, local.custom_apps)

  # Generate the PROXY_LINE string for the reverse proxy script.
  proxy_mappings_str = join(" ", [
    for app in local.additional_apps :
    format("%d:%s:%d", app.local_port, app.remote_host, app.remote_port)
    if app.original_url != null && app.original_url != ""
  ])
}

resource "terraform_data" "validate_names" {
  triggers_replace = [
    local.custom_containers
  ]

  lifecycle {
    precondition {
      condition     = length([for c in local.custom_containers : c.name]) == length(distinct([for c in local.custom_containers : c.name]))
      error_message = "Duplicate container names detected. Each container must have a unique name."
    }
    precondition {
      condition     = length(setintersection([for c in local.custom_containers : c.name], var.reserved_container_names)) == 0
      error_message = "Container name is reserved. The following names are reserved and cannot be used: ${join(", ", var.reserved_container_names)}"
    }
  }
}

data "coder_workspace_preset" "redis" {
  name        = "redis"
  description = "Redis Cache"
  icon        = local.icon.redis
  parameters = {
    "container_1_name"             = "redis-service",
    "container_1_image"            = "redis:7-alpine",
    "container_1_ports"            = "6379",
    "container_1_local_port"       = "19000",
    "container_1_volume_mounts"    = jsonencode(["redis:/data"]),
    "container_1_create_coder_app" = "false",
    "custom_container_count"       = 1,
    "container_1_env_vars"         = "",
  }
}

data "coder_workspace_preset" "postgres" {
  name        = "postgres"
  description = "PostgreSQL Database"
  icon        = local.icon.postgres
  parameters = {
    "container_1_name"             = "postgres-service",
    "container_1_image"            = "postgres:15-alpine",
    "container_1_ports"            = "5432",
    "container_1_local_port"       = "19001",
    "container_1_volume_mounts"    = jsonencode(["postgres:/var/lib/postgresql/data"]),
    "container_1_create_coder_app" = "false",
    "custom_container_count"       = 1,
    "container_1_env_vars" = join("\n", [
      "POSTGRES_DB=${local.sanitized_workspace_name}",
      "POSTGRES_USER=embold",
      "POSTGRES_PASSWORD=embold"
    ]),
  }
}

data "coder_workspace_preset" "mysql" {
  name        = "mysql"
  description = "MySQL Database"
  icon        = local.icon.mysql
  parameters = {
    "container_1_name"             = "mysql-service",
    "container_1_image"            = "mysql:8.0",
    "container_1_ports"            = "3306",
    "container_1_local_port"       = "19002",
    "container_1_volume_mounts"    = jsonencode(["mysql:/var/lib/mysql"]),
    "container_1_create_coder_app" = "false",
    "custom_container_count"       = 1,
    "container_1_env_vars" = join("\n", [
      "MYSQL_ROOT_PASSWORD=embold",
      "MYSQL_DATABASE=${local.sanitized_workspace_name}",
      "MYSQL_USER=embold",
      "MYSQL_PASSWORD=embold"
    ]),
  }
}

data "coder_workspace_preset" "mongo" {
  name        = "mongo"
  description = "MongoDB Database"
  icon        = local.icon.mongo
  parameters = {
    "container_1_name"             = "mongo-service",
    "container_1_image"            = "mongo:7",
    "container_1_ports"            = "27017",
    "container_1_local_port"       = "19003",
    "container_1_volume_mounts"    = jsonencode(["mongo:/data/db"]),
    "container_1_create_coder_app" = "false",
    "custom_container_count"       = 1,
    "container_1_env_vars" = join("\n", [
      "MONGO_INITDB_ROOT_USERNAME=embold",
      "MONGO_INITDB_ROOT_PASSWORD=embold"
    ]),
  }
}

# --- Section: Parameters for Additional Volumes ---
data "coder_parameter" "additional_volumes" {
  name         = "additional_volumes"
  display_name = "Additional Volumes to Create"
  description  = <<-DESC
    List of all persistent volume names to create for this workspace. You can then mount them into containers below.

    Example: `my-cache,shared-uploads`
  DESC
  icon         = local.icon.folder
  type         = "list(string)"
  form_type    = "tag-select"
  mutable      = true
  default      = jsonencode([])
  order        = var.order + 1
}

data "coder_parameter" "custom_container_count" {
  name         = "custom_container_count"
  display_name = "Additional Container Count"
  description  = "Number of additional Docker containers to create (0-3). Set to 0 to skip adding containers."
  type         = "number"
  icon         = local.icon.docker
  form_type    = "slider"
  mutable      = true
  default      = 0
  order        = var.order + 2
  validation {
    min = 0
    max = 3
  }
}

# --- Fixed parameter sets for up to 3 containers (leave blank to skip) ---
data "coder_parameter" "container_1_name" {
  # Always present to preserve entered values; selection controlled later by custom_container_count
  count        = data.coder_parameter.custom_container_count.value >= 1 ? 1 : 0
  name         = "container_1_name"
  display_name = "Container #1: Name"
  description  = local.desc.container_name
  type         = "string"
  icon         = local.icon.nametag
  mutable      = true
  default      = ""
  order        = var.order + 3
  validation {
    regex = "^$|^[a-zA-Z0-9][a-zA-Z0-9_-]{0,62}$"
    error = "Container name must start with alphanumeric character, contain only letters, numbers, hyphens, and underscores, and be 1-63 characters long."
  }
}

data "coder_parameter" "container_1_image" {
  count        = data.coder_parameter.custom_container_count.value >= 1 ? 1 : 0
  name         = "container_1_image"
  display_name = "Container #1: Image"
  description  = local.desc.container_image
  icon         = local.icon.docker
  type         = "string"
  mutable      = true
  default      = ""
  order        = var.order + 4
  validation {
    regex = "^$|^[a-z0-9._/-]+:[a-zA-Z0-9._-]+$|^[a-z0-9._/-]+$"
    error = "Image must be a valid Docker image name (optionally with tag)."
  }
}

data "coder_parameter" "container_1_ports" {
  count        = data.coder_parameter.custom_container_count.value >= 1 ? 1 : 0
  name         = "container_1_ports"
  display_name = "Container #1: Container Port"
  description  = local.desc.container_port
  icon         = local.icon.socket
  type         = "string"
  mutable      = true
  default      = ""
  order        = var.order + 5
  validation {
    regex = "^$|^([1-9][0-9]{0,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$"
    error = "Port must be a valid number between 1 and 65535."
  }
}

data "coder_parameter" "container_1_local_port" {
  count        = data.coder_parameter.custom_container_count.value >= 1 ? 1 : 0
  name         = "container_1_local_port"
  display_name = "Container #1: Local Proxy Port"
  description  = local.desc.local_port
  icon         = local.icon.socket
  type         = "string"
  mutable      = true
  default      = ""
  order        = var.order + 6
  validation {
    regex = "^$|^(19[0-9]{3}|20000)$"
    error = "Local port must be between 19000 and 20000."
  }
}

data "coder_parameter" "container_1_volume_mounts" {
  count        = data.coder_parameter.custom_container_count.value >= 1 ? 1 : 0
  name         = "container_1_volume_mounts"
  display_name = "Container #1: Volume Mounts"
  description  = local.desc.volume_mounts
  type         = "list(string)"
  form_type    = "tag-select"
  icon         = local.icon.folder
  mutable      = true
  default      = jsonencode([])
  order        = var.order + 7
}

data "coder_parameter" "container_1_env_vars" {
  count        = data.coder_parameter.custom_container_count.value >= 1 ? 1 : 0
  name         = "container_1_env_vars"
  display_name = "Container #1: Environment Variables"
  description  = local.desc.env_vars
  form_type    = "textarea"
  type         = "string"
  icon         = local.icon.environment
  mutable      = true
  default      = ""
  order        = var.order + 8
  styling = jsonencode({
    placeholder = <<-PL
    NODE_ENV=production
    DEBUG=false
    PL
  })
}

data "coder_parameter" "container_1_create_coder_app" {
  count        = data.coder_parameter.custom_container_count.value >= 1 ? 1 : 0
  name         = "container_1_create_coder_app"
  display_name = "Container #1: Create Coder App?"
  description  = "Automatically create a Coder app button to access this container's web interface"
  type         = "bool"
  icon         = local.icon.globe
  mutable      = true
  default      = "false"
  order        = var.order + 9
}

data "coder_parameter" "container_2_name" {
  count        = data.coder_parameter.custom_container_count.value >= 2 ? 1 : 0
  name         = "container_2_name"
  display_name = "Container #2: Name"
  description  = local.desc.container_name
  type         = "string"
  icon         = local.icon.nametag
  mutable      = true
  default      = ""
  order        = var.order + 9
  validation {
    regex = "^$|^[a-zA-Z0-9][a-zA-Z0-9_-]{0,62}$"
    error = "Container name must start with alphanumeric character, contain only letters, numbers, hyphens, and underscores, and be 1-63 characters long."
  }
}

data "coder_parameter" "container_2_image" {
  count        = data.coder_parameter.custom_container_count.value >= 2 ? 1 : 0
  name         = "container_2_image"
  display_name = "Container #2: Image"
  description  = local.desc.container_image
  icon         = local.icon.docker
  type         = "string"
  mutable      = true
  default      = ""
  order        = var.order + 10
  validation {
    regex = "^$|^[a-z0-9._/-]+:[a-zA-Z0-9._-]+$|^[a-z0-9._/-]+$"
    error = "Image must be a valid Docker image name (optionally with tag)."
  }
}

data "coder_parameter" "container_2_ports" {
  count        = data.coder_parameter.custom_container_count.value >= 2 ? 1 : 0
  name         = "container_2_ports"
  display_name = "Container #2: Container Port"
  description  = local.desc.container_port
  icon         = local.icon.socket
  type         = "string"
  mutable      = true
  default      = ""
  order        = var.order + 11
  validation {
    regex = "^$|^([1-9][0-9]{0,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$"
    error = "Port must be a valid number between 1 and 65535."
  }
}

data "coder_parameter" "container_2_local_port" {
  count        = data.coder_parameter.custom_container_count.value >= 2 ? 1 : 0
  name         = "container_2_local_port"
  display_name = "Container #2: Local Proxy Port"
  description  = local.desc.local_port
  icon         = local.icon.socket
  type         = "string"
  mutable      = true
  default      = ""
  order        = var.order + 12
  validation {
    regex = "^$|^(19[0-9]{3}|20000)$"
    error = "Local port must be between 19000 and 20000."
  }
}

data "coder_parameter" "container_2_volume_mounts" {
  count        = data.coder_parameter.custom_container_count.value >= 2 ? 1 : 0
  name         = "container_2_volume_mounts"
  display_name = "Container #2: Volume Mounts"
  description  = local.desc.volume_mounts
  type         = "list(string)"
  form_type    = "tag-select"
  icon         = local.icon.folder
  mutable      = true
  default      = jsonencode([])
  order        = var.order + 13
}

data "coder_parameter" "container_2_env_vars" {
  count        = data.coder_parameter.custom_container_count.value >= 2 ? 1 : 0
  name         = "container_2_env_vars"
  display_name = "Container #2: Environment Variables"
  description  = local.desc.env_vars
  form_type    = "textarea"
  type         = "string"
  icon         = local.icon.environment
  mutable      = true
  default      = ""
  order        = var.order + 14
  styling = jsonencode({
    placeholder = <<-PL
    NODE_ENV=production
    DEBUG=false
    PL
  })
}

data "coder_parameter" "container_2_create_coder_app" {
  count        = data.coder_parameter.custom_container_count.value >= 2 ? 1 : 0
  name         = "container_2_create_coder_app"
  display_name = "Container #2: Create Coder App?"
  description  = "Automatically create a Coder app button to access this container's web interface"
  type         = "bool"
  icon         = local.icon.globe
  mutable      = true
  default      = "false"
  order        = var.order + 15
}

data "coder_parameter" "container_3_name" {
  count        = data.coder_parameter.custom_container_count.value >= 3 ? 1 : 0
  name         = "container_3_name"
  display_name = "Container #3: Name"
  description  = local.desc.container_name
  type         = "string"
  icon         = local.icon.nametag
  mutable      = true
  default      = ""
  order        = var.order + 16
  validation {
    regex = "^$|^[a-zA-Z0-9][a-zA-Z0-9_-]{0,62}$"
    error = "Container name must start with alphanumeric character, contain only letters, numbers, hyphens, and underscores, and be 1-63 characters long."
  }
}

data "coder_parameter" "container_3_image" {
  count        = data.coder_parameter.custom_container_count.value >= 3 ? 1 : 0
  name         = "container_3_image"
  display_name = "Container #3: Image"
  description  = local.desc.container_image
  icon         = local.icon.docker
  type         = "string"
  mutable      = true
  default      = ""
  order        = var.order + 17
  validation {
    regex = "^$|^[a-z0-9._/-]+:[a-zA-Z0-9._-]+$|^[a-z0-9._/-]+$"
    error = "Image must be a valid Docker image name (optionally with tag)."
  }
}

data "coder_parameter" "container_3_ports" {
  count        = data.coder_parameter.custom_container_count.value >= 3 ? 1 : 0
  name         = "container_3_ports"
  display_name = "Container #3: Container Port"
  description  = local.desc.container_port
  icon         = local.icon.socket
  type         = "string"
  mutable      = true
  default      = ""
  order        = var.order + 18
  validation {
    regex = "^$|^([1-9][0-9]{0,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$"
    error = "Port must be a valid number between 1 and 65535."
  }
}

data "coder_parameter" "container_3_local_port" {
  count        = data.coder_parameter.custom_container_count.value >= 3 ? 1 : 0
  name         = "container_3_local_port"
  display_name = "Container #3: Local Proxy Port"
  description  = local.desc.local_port
  icon         = local.icon.socket
  type         = "string"
  mutable      = true
  default      = ""
  order        = var.order + 19
  validation {
    regex = "^$|^(19[0-9]{3}|20000)$"
    error = "Local port must be between 19000 and 20000."
  }
}

data "coder_parameter" "container_3_volume_mounts" {
  count        = data.coder_parameter.custom_container_count.value >= 3 ? 1 : 0
  name         = "container_3_volume_mounts"
  display_name = "Container #3: Volume Mounts"
  description  = local.desc.volume_mounts
  type         = "list(string)"
  form_type    = "tag-select"
  icon         = local.icon.folder
  mutable      = true
  default      = jsonencode([])
  order        = var.order + 20
}

data "coder_parameter" "container_3_env_vars" {
  count        = data.coder_parameter.custom_container_count.value >= 3 ? 1 : 0
  name         = "container_3_env_vars"
  display_name = "Container #3: Environment Variables"
  description  = local.desc.env_vars
  form_type    = "textarea"
  type         = "string"
  icon         = local.icon.environment
  mutable      = true
  default      = ""
  order        = var.order + 21
  styling = jsonencode({
    placeholder = <<-PL
    NODE_ENV=production
    DEBUG=false
    PL
  })
}

data "coder_parameter" "container_3_create_coder_app" {
  count        = data.coder_parameter.custom_container_count.value >= 3 ? 1 : 0
  name         = "container_3_create_coder_app"
  display_name = "Container #3: Create Coder App?"
  description  = "Automatically create a Coder app button to access this container's web interface"
  type         = "bool"
  icon         = local.icon.globe
  mutable      = true
  default      = "false"
  order        = var.order + 22
}

data "coder_parameter" "custom_coder_app_count" {
  name         = "custom_coder_app_count"
  display_name = "Additional Coder App Count"
  description  = "Number of additional Coder Apps to create (0-3). Set to 0 to skip adding apps."
  type         = "number"
  icon         = local.icon.quantity
  form_type    = "slider"
  mutable      = true
  default      = 0
  order        = var.order + 23
  validation {
    min = 0
    max = 3
  }
}

# --- Fixed parameter sets for up to 3 additional Coder apps ---
data "coder_parameter" "app_1_name" {
  count        = try(tonumber(data.coder_parameter.custom_coder_app_count.value), 0) >= 1 ? 1 : 0
  name         = "app_1_name"
  display_name = "Coder App #1: Name"
  type         = "string"
  icon         = local.icon.nametag
  mutable      = true
  default      = ""
  order        = var.order + 24
}

data "coder_parameter" "app_1_slug" {
  count        = try(tonumber(data.coder_parameter.custom_coder_app_count.value), 0) >= 1 ? 1 : 0
  name         = "app_1_slug"
  display_name = "Coder App #1: Slug"
  description  = local.desc.app_slug
  type         = "string"
  icon         = local.icon.tag
  mutable      = true
  default      = ""
  order        = var.order + 25
  validation {
    regex = "^$|^[a-z0-9][a-z0-9_-]{0,31}$"
    error = "Slug must be lowercase, start with alphanumeric, and contain only letters, numbers, hyphens, underscores (max 32 chars)."
  }
}

data "coder_parameter" "app_1_url" {
  count        = try(tonumber(data.coder_parameter.custom_coder_app_count.value), 0) >= 1 ? 1 : 0
  name         = "app_1_url"
  display_name = "Coder App #1: URL"
  description  = local.desc.app_url
  type         = "string"
  icon         = local.icon.paperclip
  mutable      = true
  default      = ""
  order        = var.order + 26
  validation {
    regex = "^$|^https?://[a-zA-Z0-9.-]+(:([1-9][0-9]{0,4}))?(/.*)?$"
    error = "URL must be a valid HTTP/HTTPS URL with optional port and path."
  }
}

data "coder_parameter" "app_1_icon" {
  count        = try(tonumber(data.coder_parameter.custom_coder_app_count.value), 0) >= 1 ? 1 : 0
  name         = "app_1_icon"
  display_name = "Coder App #1: Icon"
  description  = local.desc.app_icon
  type         = "string"
  icon         = "/icon/image.svg"
  mutable      = true
  default      = ""
  order        = var.order + 27
}

data "coder_parameter" "app_1_share" {
  count        = try(tonumber(data.coder_parameter.custom_coder_app_count.value), 0) >= 1 ? 1 : 0
  name         = "app_1_share"
  display_name = "Coder App #1: Share Level"
  type         = "string"
  icon         = local.icon.share_permission
  default      = "owner"
  mutable      = true
  order        = var.order + 28
  option {
    name  = "Owner"
    value = "owner"
  }
  option {
    name  = "Authenticated"
    value = "authenticated"
  }
  option {
    name  = "Public"
    value = "public"
  }
}

data "coder_parameter" "app_2_name" {
  count        = try(tonumber(data.coder_parameter.custom_coder_app_count.value), 0) >= 2 ? 1 : 0
  name         = "app_2_name"
  display_name = "Coder App #2: Name"
  type         = "string"
  icon         = local.icon.nametag
  mutable      = true
  default      = ""
  order        = var.order + 29
}

data "coder_parameter" "app_2_slug" {
  count        = try(tonumber(data.coder_parameter.custom_coder_app_count.value), 0) >= 2 ? 1 : 0
  name         = "app_2_slug"
  display_name = "Coder App #2: Slug"
  description  = <<-DESC
    URL-safe identifier (lowercase, hyphens, underscores).

    Example: `adminer`
  DESC
  type         = "string"
  icon         = local.icon.tag
  mutable      = true
  default      = ""
  order        = var.order + 30
  validation {
    regex = "^$|^[a-z0-9][a-z0-9_-]{0,31}$"
    error = "Slug must be lowercase, start with alphanumeric, and contain only letters, numbers, hyphens, underscores (max 32 chars)."
  }
}

data "coder_parameter" "app_2_url" {
  count        = try(tonumber(data.coder_parameter.custom_coder_app_count.value), 0) >= 2 ? 1 : 0
  name         = "app_2_url"
  display_name = "Coder App #2: URL"
  description  = <<-DESC
    Internal service URL reachable from the workspace.

    Example: `http://adminer:8080`
  DESC
  type         = "string"
  icon         = local.icon.paperclip
  mutable      = true
  default      = ""
  order        = var.order + 31
  validation {
    regex = "^$|^https?://[a-zA-Z0-9.-]+(:([1-9][0-9]{0,4}))?(/.*)?$"
    error = "URL must be a valid HTTP/HTTPS URL with optional port and path."
  }
}

data "coder_parameter" "app_2_icon" {
  count        = try(tonumber(data.coder_parameter.custom_coder_app_count.value), 0) >= 2 ? 1 : 0
  name         = "app_2_icon"
  display_name = "Coder App #2: Icon"
  description  = <<-DESC
    Icon path or emoji code for the app.

    Example: `/icon/adminer.svg`
  DESC
  type         = "string"
  icon         = "/icon/image.svg"
  mutable      = true
  default      = ""
  order        = var.order + 32
}

data "coder_parameter" "app_2_share" {
  count        = try(tonumber(data.coder_parameter.custom_coder_app_count.value), 0) >= 2 ? 1 : 0
  name         = "app_2_share"
  display_name = "Coder App #2: Share Level"
  type         = "string"
  icon         = local.icon.share_permission
  default      = "owner"
  mutable      = true
  order        = var.order + 33
  option {
    name  = "Owner"
    value = "owner"
  }
  option {
    name  = "Authenticated"
    value = "authenticated"
  }
  option {
    name  = "Public"
    value = "public"
  }
}

data "coder_parameter" "app_3_name" {
  count        = try(tonumber(data.coder_parameter.custom_coder_app_count.value), 0) >= 3 ? 1 : 0
  name         = "app_3_name"
  display_name = "Coder App #3: Name"
  type         = "string"
  icon         = local.icon.nametag
  mutable      = true
  default      = ""
  order        = var.order + 34
}

data "coder_parameter" "app_3_slug" {
  count        = try(tonumber(data.coder_parameter.custom_coder_app_count.value), 0) >= 3 ? 1 : 0
  name         = "app_3_slug"
  display_name = "Coder App #3: Slug"
  description  = <<-DESC
    URL-safe identifier (lowercase, hyphens, underscores).

    Example: `mailpit`
  DESC
  type         = "string"
  icon         = local.icon.tag
  mutable      = true
  default      = ""
  order        = var.order + 35
  validation {
    regex = "^$|^[a-z0-9][a-z0-9_-]{0,31}$"
    error = "Slug must be lowercase, start with alphanumeric, and contain only letters, numbers, hyphens, underscores (max 32 chars)."
  }
}

data "coder_parameter" "app_3_url" {
  count        = try(tonumber(data.coder_parameter.custom_coder_app_count.value), 0) >= 3 ? 1 : 0
  name         = "app_3_url"
  display_name = "Coder App #3: URL"
  description  = <<-DESC
    Internal service URL reachable from the workspace.

    Example: `http://mailpit:8025`
  DESC
  type         = "string"
  icon         = local.icon.paperclip
  mutable      = true
  default      = ""
  order        = var.order + 36
  validation {
    regex = "^$|^https?://[a-zA-Z0-9.-]+(:([1-9][0-9]{0,4}))?(/.*)?$"
    error = "URL must be a valid HTTP/HTTPS URL with optional port and path."
  }
}

data "coder_parameter" "app_3_icon" {
  count        = try(tonumber(data.coder_parameter.custom_coder_app_count.value), 0) >= 3 ? 1 : 0
  name         = "app_3_icon"
  display_name = "Coder App #3: Icon"
  description  = <<-DESC
    Icon path or emoji code for the app.

    Example: `https://mailpit.axllent.org/images/mailpit.svg`
  DESC
  type         = "string"
  icon         = "/icon/image.svg"
  mutable      = true
  default      = ""
  order        = var.order + 37
}

data "coder_parameter" "app_3_share" {
  count        = try(tonumber(data.coder_parameter.custom_coder_app_count.value), 0) >= 3 ? 1 : 0
  name         = "app_3_share"
  display_name = "Coder App #3: Share Level"
  type         = "string"
  icon         = local.icon.share_permission
  default      = "owner"
  mutable      = true
  order        = var.order + 38
  option {
    name  = "Owner"
    value = "owner"
  }
  option {
    name  = "Authenticated"
    value = "authenticated"
  }
  option {
    name  = "Public"
    value = "public"
  }
}

# --- Section: Resource Creation ---
resource "docker_volume" "dynamic_resource_volume" {
  # Only create volumes if the workspace is running
  for_each = data.coder_workspace.me.start_count > 0 ? toset(local.volume_names_to_create) : []
  # Use the original volume name as key but generate a Docker volume name that includes a prefix.
  # If the volume came from a preset, prefix with preset-<n>, otherwise custom-<n>.
  name = "${var.resource_name_base}-${each.key}"
  lifecycle {
    ignore_changes = all
  }
  # Label volumes so they can be associated with the Coder agent and workspace
  labels {
    label = "coder.agent_id"
    value = var.agent_id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "coder.volume_key"
    value = each.key
  }
}

resource "docker_container" "dynamic_resource_container" {
  # Only create containers if the workspace is running.
  for_each = data.coder_workspace.me.start_count > 0 ? local.all_containers_map : tomap({})
  name = (
    startswith(each.key, "custom-")
    ? "${var.resource_name_base}-custom-${each.value.custom_index}"
    : "${var.resource_name_base}-${each.value.name}"
  )
  image        = each.value.image
  hostname     = each.value.name
  network_mode = var.docker_network_name
  env          = each.value.env
  #   restart      = "unless-stopped"

  # Resource limits to prevent containers from consuming excessive resources
  memory      = var.container_memory_limit
  memory_swap = var.container_memory_limit # Disable swap usage
  cpu_shares  = 1024                       # Default CPU shares

  # Security options
  user      = var.container_user_id != null ? var.container_user_id : null
  read_only = false # Allow writes to container filesystem
  tmpfs = {
    "/tmp" = "noexec,nosuid,size=100m"
  }

  # Label containers so they can be associated with the Coder agent and workspace
  labels {
    label = "coder.agent_id"
    value = var.agent_id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "coder.resource_key"
    value = each.key
  }

  # Health check for better container management
  healthcheck {
    test         = ["CMD-SHELL", "exit 0"] # Basic health check - containers should override this
    interval     = "30s"
    timeout      = "3s"
    start_period = "10s"
    retries      = 3
  }

  # Dynamically expose internal ports without publishing to the host.
  # dynamic "ports" {
  #   for_each = toset(each.value.ports)
  #   content {
  #     internal = ports.value
  #   }
  # }

  # Use a dynamic block to create volume mounts for this container.
  # Separate named Docker volumes (created via docker_volume) from host bind paths.
  # This prevents invalid index errors when a mount key is actually a host path.
  dynamic "volumes" {
    for_each = { for k, v in each.value.mounts : k => v if contains(keys(docker_volume.dynamic_resource_volume), k) }
    content {
      container_path = volumes.value
      volume_name    = docker_volume.dynamic_resource_volume[volumes.key].name
      read_only      = false
    }
  }
  dynamic "volumes" {
    for_each = { for k, v in each.value.mounts : k => v if !contains(keys(docker_volume.dynamic_resource_volume), k) }
    content {
      container_path = volumes.value
      host_path      = volumes.key
      read_only      = false
    }
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes to image after creation to prevent unwanted updates
      image,
    ]
  }
}

resource "coder_script" "dynamic_resources_reverse_proxy" {
  count              = data.coder_workspace.me.start_count
  agent_id           = var.agent_id
  display_name       = "Dynamic Resources Proxy"
  icon               = local.icon.globe
  run_on_start       = true
  start_blocks_login = false # Don't block login, it runs in background
  script             = templatefile("${path.module}/run.sh", { PROXY_LINE = local.proxy_mappings_str })
}

# Create the Coder apps to expose the services
resource "coder_app" "dynamic_app" {
  # Only create apps if the workspace is running
  for_each = data.coder_workspace.me.start_count > 0 ? { for app in local.additional_apps : app.slug => app if app.name != null && app.name != "" && app.slug != null && app.slug != "" } : {}

  agent_id     = var.agent_id
  slug         = each.value.slug
  display_name = each.value.name
  url          = each.value.proxy_url
  icon         = each.value.icon
  share        = each.value.share
  subdomain    = true
  order        = 2
}

# Display metadata for each dynamic container showing how to reach them
resource "coder_metadata" "dynamic_container_info" {
  for_each    = data.coder_workspace.me.start_count > 0 ? local.all_containers_map : tomap({})
  resource_id = docker_container.dynamic_resource_container[each.key].id
  item {
    key   = "Hostname"
    value = each.value.name
  }
  # item {
  #   key   = "Image"
  #   value = each.value.image
  # }
  # item {
  #   key   = "Type"
  #   value = startswith(each.key, "preset-") ? "Preset" : "Custom"
  # }
}
