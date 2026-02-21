#!/usr/bin/env bash
set -euo pipefail

# Check if socat is installed
if ! command -v socat >/dev/null 2>&1; then
  echo "socat command not found; please install socat to use the reverse proxy functionality"
  exit 1
fi

# Rendered by Terraform templatefile. PROXY_LINE is a space-separated list of
# mappings like "8080:internal.service:80".
PROXY_LINE="${PROXY_LINE}"

# Exit if there are no proxies to create.
if [[ -z "$PROXY_LINE" ]]; then
  exit 0
fi

RUNDIR="$${XDG_RUNTIME_DIR:-/tmp}/dynamic-resources-reverse-proxy"
mkdir -p "$RUNDIR" || true

for m in $PROXY_LINE; do
  # Parse mapping — use escaped shell parameter expansions so templatefile() doesn't try to evaluate them
  local_port="$${m%%:*}"
  rest="$${m#*:}"
  remote_host="$${rest%%:*}"
  remote_port="$${rest##*:}"

  echo "Starting proxy: local $local_port -> $remote_host:$remote_port"
  # Run socat in background; use nohup so it survives the script exit if needed
  nohup socat TCP-LISTEN:$local_port,reuseaddr,fork TCP:$remote_host:$remote_port >"$RUNDIR/reverse-proxy-$local_port.log" 2>&1 &
done
