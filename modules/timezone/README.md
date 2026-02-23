# Timezone module

Coder module that provisions a small `coder_script` that sets the container timezone inside
the workspace. It is rendered via `templatefile()` so the runtime script is editable and
testable.

## Inputs

- `agent_id` - coder agent id
- `count` - number of script instances
- `timezone` - timezone string, e.g. `America/New_York`. If empty, the script is a no-op.

## Usage

```terraform
module "timezone" {
  source   = "git::https://github.com/emboldagency/coder-registry.git//modules/timezone?ref=main"
  count    = data.coder_workspace.me.start_count
  agent_id = coder_agent.example.id
}
```

Set the time zone explicitly:

```terraform
module "timezone" {
  source   = "git::https://github.com/emboldagency/coder-registry.git//modules/timezone?ref=main"
  count    = data.coder_workspace.me.start_count
  agent_id = coder_agent.example.id
  timezone = "America/Los_Angeles"
}
```

## Publishing

- Tag releases with Calendar Versioning (e.g. `v2026.02.23.0`) and reference them with `?ref=` in the `git::` source string.
