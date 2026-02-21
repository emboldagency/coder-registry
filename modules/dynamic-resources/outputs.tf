output "startup_script_fragment" {
  description = "A shell script fragment to be inserted into the main coder_agent startup script. Sets up socat reverse proxies."
  value       = <<-EOT
    # --- START DYNAMIC SERVICES PROXY SCRIPT ---
    set +e
    PROXY_LINE="${local.proxy_mappings_str}"
    if [[ -n "$PROXY_LINE" ]]; then
      if ! command -v socat >/dev/null 2>&1; then
        echo "ERROR: socat command not found; please install socat in the base image to use the reverse proxy." >&2
        echo "       Install with: apt-get update && apt-get install -y socat (Debian/Ubuntu)" >&2
        echo "       Install with: yum install -y socat (RHEL/CentOS)" >&2
      else
        RUNDIR="$${XDG_RUNTIME_DIR:-/tmp}/reverse-proxy"
        mkdir -p "$RUNDIR" || true
        echo "Setting up ${length(local.additional_apps)} reverse proxies for dynamic services..."
        for m in $PROXY_LINE; do
          local_port="$${m%%:*}"
          rest="$${m#*:}"
          remote_host="$${rest%%:*}"
          remote_port="$${rest##*:}"
          echo "🔗 Proxy: localhost:$local_port -> $remote_host:$remote_port"
          nohup socat TCP-LISTEN:$local_port,reuseaddr,fork TCP:$remote_host:$remote_port >"$RUNDIR/reverse-proxy-$local_port.log" 2>&1 &
        done
        echo "✅ Dynamic services proxy setup complete"
      fi
    # else
    #   echo "ℹ️  No dynamic services configured"
    fi
    set -e
    # --- END DYNAMIC SERVICES PROXY SCRIPT ---
  EOT
}

output "created_volumes" {
  description = "List of Docker volume names created by this module"
  value       = [for v in docker_volume.dynamic_resource_volume : v.name]
}

output "created_containers" {
  description = "List of Docker container names created by this module"
  value       = [for c in docker_container.dynamic_resource_container : c.name]
}

output "created_apps" {
  description = "List of Coder app slugs created by this module"
  value       = [for a in coder_app.dynamic_app : a.slug]
}
