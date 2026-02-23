# Reverse Proxy module

Coder module that starts background socat proxies inside the workspace so local ports
can be forwarded to remote internal services. It renders a script via
`templatefile()` and provisions it as a `coder_script`.

## Inputs

- `agent_id` (string)
- `proxy_mappings` (list(string)) - each entry is local_port:remote_host:remote_port

## Usage

```terraform
module "reverse_proxy" {
  source   = "git::https://github.com/emboldagency/coder-registry.git//modules/reverse-proxy?ref=main"
  count    = data.coder_workspace.me.start_count
  agent_id = coder_agent.example.id
  proxy_mappings = ["8080:internal.service:80", "8443:internal.service:443"]
}
```

## Publishing

- Tag releases with Calendar Versioning (e.g. `v2026.02.23.0`) and reference them with `?ref=` in the `git::` source string.
