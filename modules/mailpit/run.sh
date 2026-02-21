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

RUNDIR="$${XDG_RUNTIME_DIR:-/tmp}/coder-mailpit"
mkdir -p "$RUNDIR" || true

echo "Starting mailpit reverse proxy(s)"
for mapping in $PROXY_LINE; do
	# mapping is local_port:remote_host:remote_port
	IFS=':' read -r local_port remote_host remote_port <<<"$mapping"
	if [[ -z "$local_port" || -z "$remote_host" || -z "$remote_port" ]]; then
		echo "Skipping invalid mapping: $mapping"
		continue
	fi
	logfile="$RUNDIR/reverse-proxy-$${local_port}.log"
	echo "  - $${local_port} -> $${remote_host}:$${remote_port} (log: $logfile)"
	nohup socat TCP-LISTEN:$${local_port},reuseaddr,fork TCP:$${remote_host}:$${remote_port} >>"$logfile" 2>&1 &
done

echo "All proxies started."
