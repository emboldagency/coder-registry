# Coder Dynamic Resources Module

This module provides a set of Coder parameters that allow users to dynamically create additional Docker containers, Docker volumes, and Coder applications at workspace creation time.

It is useful for templates where users may need optional services like databases (Redis, Postgres), web UIs, or other tools without having to hardcode them into the template.

## Features

- **Quick Setup Presets**: One-click setup for common services (Redis, PostgreSQL, MySQL, MongoDB)
- **Dynamic Containers**: Add up to 5 additional Docker containers with resource limits and security controls
- **Dynamic Volumes**: Create persistent Docker volumes and mount them into containers
- **Dynamic Coder Apps**: Expose services running in the containers as Coder apps
- **Automatic Reverse Proxy**: Automatically configures a socat reverse proxy in the main workspace container
- **Input Validation**: Comprehensive validation for container names, ports, URLs, and environment variables
- **Resource Management**: Memory limits, CPU controls, and security settings for containers
- **Health Monitoring**: Built-in health checks and proper container lifecycle management

## Quick Setup Presets

The module includes preset configurations for common development services:

- **Redis Cache**: Redis 7 with default port 6379
- **PostgreSQL**: PostgreSQL 15 with persistent data volume
- **MySQL**: MySQL 8.0 with persistent data volume
- **MongoDB**: MongoDB 7 with persistent data volume

Simply select a preset from the "Quick Setup" dropdown to automatically configure the service.

## Usage

**Prerequisite**: Ensure `socat` is installed in your base Docker image for the main workspace container.

Add the module to your template:

```terraform
module "dynamic_services" {
    source = "git::https://github.com/emboldagency/coder-registry.git//modules/dynamic-resources?ref=main"

    agent_id            = coder_agent.main.id
    docker_network_name = docker_network.workspace[0].name
    resource_name_base  = local.resource_name_base

    # Optional: Configure resource limits (defaults shown)
    container_memory_limit = 512  # MB per container
    container_user_id     = null  # Use container default user
}
```

Update your main coder_agent's startup_script to include the proxy script from this module's output:

```terraform
resource "coder_agent" "main" {
# ... other agent configuration ...

startup_script = <<-EOT
    ${module.dynamic_services.startup_script_fragment}

    # Your original startup script continues here
    echo "Hello from the main script!"

EOT
}
```

## Configuration Options

### Variables

| Variable                 | Type   | Default | Description                                             |
| ------------------------ | ------ | ------- | ------------------------------------------------------- |
| `agent_id`               | string | -       | The Coder agent ID to attach scripts and apps to        |
| `docker_network_name`    | string | -       | Docker network name for container communication         |
| `resource_name_base`     | string | -       | Unique prefix for all created Docker resources          |
| `container_memory_limit` | number | 512     | Memory limit per container in MB (64-4096)              |
| `container_user_id`      | string | null    | User ID to run containers as (null = container default) |

### User Parameters

- **Quick Setup Preset**: Choose from Redis, PostgreSQL, MySQL, MongoDB, or custom setup
- **Container Count**: Number of additional containers (0-5)
- **Container Configuration**: Per-container name, image, ports, volumes, environment variables
- **Volume Management**: List of persistent volumes to create
- **App Configuration**: Coder apps to expose container services

## Parameter Ordering and Offsets

This module creates **34 Coder parameters**. To control the order in the Coder UI, set the `order` variable when including this module:

```hcl
module "dynamic_services" {
  source = "..."
  order  = 0 # or offset from previous modules
  # ...other variables...
}
```

Each parameter's order is calculated as `var.order + offset`, where `offset` is the parameter's index in this module (starting from 0).

**If you include multiple modules:**

- Set the `order` variable in each module to offset by the total number of parameters in previous modules.
- Example: If module A creates 10 parameters, set `order = 10` in module B so its first parameter appears after module A's last parameter.

**Parameter count in this module:**

- Quick Setup Preset: 1
- Additional Volumes: 1
- Container Count: 1
- Container 1: 5
- Container 2: 5
- Container 3: 5
- Coder App Count: 1
- Coder App 1: 5
- Coder App 2: 5
- Coder App 3: 5
- **Total:** 34

Adjust the offset as needed for your template's UI order.

## Security Features

- **Resource Limits**: Configurable memory limits prevent container resource exhaustion
- **Port Validation**: Only valid port ranges (1-65535) are accepted
- **Input Validation**: Container names, URLs, and environment variables are validated
- **User Controls**: Optional user ID specification for container security
- **Network Isolation**: Containers run on specified Docker network only
- **Health Monitoring**: Built-in health checks for container management

## Outputs

The module provides several outputs for integration with other resources:

```terraform
# Access created resource information
output "volumes" {
  value = module.dynamic_services.created_volumes
}

output "containers" {
  value = module.dynamic_services.created_containers
}

output "apps" {
  value = module.dynamic_services.created_apps
}
```
