# coder-mailpit

Terraform module to provision Mailpit as a standalone module for Coder templates.

This module creates:

- A Docker volume for Mailpit data
- A Docker container running `axllent/mailpit:latest`
- A `coder_app` entry so Mailpit is exposed in the Coder UI
- A `coder_script` that runs a small `socat` reverse-proxy in the main workspace container to expose Mailpit to the host

This module is intended to be included by workspace templates that want to provide Mailpit as a dev service.

## Requirements

- The workspace agent image must include `socat` (the proxy script runs in the agent container)
- Docker and the Terraform Docker provider must be available on the host where the template applies

## Example usage

```hcl
module "mailpit" {
  source            = "git::https://github.com/emboldagency/coder-registry.git//modules/mailpit?ref=main"
  agent_id            = coder_agent.main.id
  docker_network_name = docker_network.workspace[0].name
  resource_name_base  = "coder-${data.coder_workspace.me.id}"
  proxy_mappings      = ["18025:mailpit:8025"]
}
```

## Variables

- `agent_id` (string) - Coder agent id to attach the proxy script and app to
- `docker_network_name` (string) - Docker network for the container
- `resource_name_base` (string) - Unique name prefix for docker resources
- `container_memory_limit` (number) - Memory limit per container (MB). Default: 512
- `container_user_id` (string|null) - Optional UID to run containers as
- `proxy_mappings` (list(string)) - Optional list of mappings `local_port:remote_host:remote_port`. Default: `['18025:mailpit:8025']`

## Notes

- If your agent image doesn't have `socat`, install it or use a different reverse-proxy approach (nginx, or configure coder reverse proxy).
- The module pulls `axllent/mailpit:latest`. If you need a pinned version, modify `main.tf` to reference a specific tag.

## Outputs

- none currently; you can add outputs to return the docker volume or container names
