terraform {
  required_providers {
    coder = { source = "coder/coder" }
  }
}

resource "coder_script" "reverse_proxy" {
  agent_id           = var.agent_id
  script             = templatefile("${path.module}/run.sh", { PROXY_LINE = join(" ", var.proxy_mappings) })
  display_name       = "Reverse Proxy"
  icon               = "https://api.embold.net/icons?name=socat.svg"
  run_on_start       = true
  start_blocks_login = true
}
