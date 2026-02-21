#!/usr/bin/env bash
set -euo pipefail

# Rendered by Terraform templatefile. TIMEZONE will be substituted at render time.
TIMEZONE="${TIMEZONE}"

if [ -z "$TIMEZONE" ]; then
  echo "No TIMEZONE provided; skipping timezone setup"
  exit 0
fi

if [ -f "/usr/share/zoneinfo/$TIMEZONE" ]; then
  echo "Setting timezone to $TIMEZONE"
  if sudo ln -snf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime && echo "$TIMEZONE" | sudo tee /etc/timezone >/dev/null; then
    echo "Timezone set to $TIMEZONE successfully"
  else
    echo "WARN: Failed to set timezone to $TIMEZONE"
  fi
else
  echo "WARN: timezone file /usr/share/zoneinfo/$TIMEZONE not found; skipping"
fi
