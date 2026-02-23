# Embold Coder Registry

![Calendar Semantic Versioning](https://embold.net/api/github/badge/calsemver.php?repo=coder-registry)

A centralized collection of Terraform modules used for provisioning and configuring Coder workspaces at Embold.

## Available Modules

| Module                                               | Description                                                             |
| ---------------------------------------------------- | ----------------------------------------------------------------------- |
| [**Adminer**](./modules/adminer)                     | Deploys an Adminer database management container proxy.                 |
| [**Dotfiles**](./modules/dotfiles)                   | Links dotfiles into the workspace container.                            |
| [**Dynamic Resources**](./modules/dynamic-resources) | Dynamically create additional Docker containers, volumes, and apps.     |
| [**Home Setup**](./modules/home-setup)               | Configures the `/home/embold` directory structure and user permissions. |
| [**Mailpit**](./modules/mailpit)                     | Deploys a Mailpit container to capture and test outbound emails.        |
| [**Reverse Proxy**](./modules/reverse-proxy)         | Creates a reverse proxy using `socat` for workspace forwarding.         |
| [**SSH Setup**](./modules/ssh-setup)                 | Provisions SSH host keys and configurations securely.                   |
| [**Timezone**](./modules/timezone)                   | Automatically sets the workspace timezone based on the agent parameter. |

## Usage

Source modules directly into your Coder templates using Terraform's Git syntax:

```hcl
module "timezone" {
  source   = "git::https://github.com/emboldagency/coder-registry.git//modules/timezone?ref=main"
  agent_id = coder_agent.main.id
}
```

## Versioning

This repository uses Calendar Versioning based on dates + zero based patch (e.g., `v2026.02.20.0`). To ensure stability, pin your template module source URLs to a specific release tag rather than the `main` branch.
