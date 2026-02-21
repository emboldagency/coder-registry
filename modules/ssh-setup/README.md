# SSH Setup module

Coder module that provisions a small `coder_script` that runs in Coder workspaces to ensure a sensible `~/.ssh/known_hosts` and basic Git SSH configuration (including the workspace-provided SSH key used for commit signing).

## Inputs

- `agent_id` (string) - The coder agent id to attach the script to.
- `count` (number) - How many agent scripts to create (usually workspace start_count).
- `hosts` (list(string)) - A list of hosts to add to known_hosts. Each entry may be either
  a hostname or a host:port pair. Example: `"git.internal:2222"` or `"github.com"`.

## Usage

```terraform
module "ssh_setup" {
  source   = "git::https://github.com/emboldagency/coder-registry.git//modules/ssh-setup?ref=main"
  count    = data.coder_workspace.me.start_count
  agent_id = coder_agent.example.id
}
```

Set hosts for the known_hosts file:

```terraform
module "ssh_setup" {
  source   = "git::https://github.com/emboldagency/coder-registry.git//modules/ssh-setup?ref=main"
  count    = data.coder_workspace.me.start_count
  agent_id = coder_agent.example.id
  hosts    = ["github.com", "git.internal:2222"]
}
```

## Notes

- The module renders the `hosts` list into the script using Terraform interpolation and
  carefully escapes shell `${...}` sequences so Terraform will not attempt to interpolate them.
- The script is idempotent: it will deduplicate known_hosts entries and avoid overwriting
  an existing `~/.ssh` directory.

## Publishing

- Tag releases with SemVer (e.g. `v1.0.0`) and reference them with `?ref=` in the `git::` source string.
