terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
  }
}

resource "coder_script" "ssh_setup" {
  agent_id           = var.agent_id
  script             = templatefile("${path.module}/run.sh", { HOSTS_LINE = join(" ", var.hosts) })
  display_name       = "SSH Setup"
  icon               = "https://api.embold.net/icons/ssh.svg"
  run_on_start       = true
  start_blocks_login = true
}
