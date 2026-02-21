# coder-adminer

Terraform module to provision Adminer as a standalone module for Coder templates.

This module creates:

- A Docker container running the official `adminer:latest` image
- A `coder_app` entry so Adminer is exposed in the Coder UI
- A `coder_script` that runs a small `socat` reverse-proxy in the main workspace container to expose Adminer to the host

This module is intended to be included by workspace templates that want to provide Adminer (a lightweight DB GUI) as a dev service.

## Requirements

- The workspace agent image must include `socat` (the proxy script runs in the agent container)
- Docker and the Terraform Docker provider must be available on the host where the template applies

## Example usage

```hcl
module "adminer" {
  source              = "git::https://github.com/emboldagency/coder-registry.git//modules/adminer?ref=main"
  agent_id            = coder_agent.main.id
  docker_network_name = docker_network.workspace[0].name
  resource_name_base  = "coder-${data.coder_workspace.me.id}"

  # Database connection (auto-filled in login form)
  db_server   = "mysql"
  db_username = "embold"
  db_password = "embold"
  db_name     = "mydatabase"
  db_driver   = "server"

  # Optional: customize theme
  adminer_design = "pappu687"

  # Optional: customize proxy mappings
  proxy_mappings = ["18080:adminer:8080"]
}
```

## Variables

### Required

- `agent_id` (string) - Coder agent id to attach the proxy script and app to
- `docker_network_name` (string) - Docker network for the container. Default: `"bridge"`
- `resource_name_base` (string) - Unique name prefix for docker resources

### Optional - Database Connection

- `db_server` (string) - Database server hostname. Default: `"mysql"`
- `db_username` (string) - Database username. Default: `"embold"`
- `db_password` (string) - Database password (sensitive). Default: `"embold"`
- `db_name` (string) - Default database name. Default: `"mysqlgit p"`
- `db_driver` (string) - Database driver (`pgsql`, `server`, `sqlite`, `oracle`, `mssql`). Default: `"server"` (mysql)

### Optional - UI & Network

- `adminer_design` (string) - Adminer theme/design name. Default: `"pappu687"`
- `proxy_mappings` (list(string)) - List of mappings `local_port:remote_host:remote_port`. Default: `["18080:adminer:8080"]`
- `container_memory_limit` (number) - Memory limit per container (MB). Default: `512`
- `container_user_id` (string|null) - Optional UID to run containers as. Default: `null`

## Notes

- If your agent image doesn't have `socat`, install it or use a different reverse-proxy approach (nginx, or configure coder reverse proxy).
- The module pulls `adminer:latest`. If you need a pinned version, modify `main.tf` to reference a specific tag.
