#!/usr/bin/env bash
set -euo pipefail

# Check if git is installed
if ! command -v git >/dev/null 2>&1; then
  echo "git command not found; please install git to use this script"
  exit 1
fi

# Check if jq is installed
if ! command -v jq >/dev/null 2>&1; then
  echo "jq command not found; please install jq to use this script"
  exit 1
fi

# This file is rendered by Terraform's templatefile() and therefore any shell
# interpolation must be written normally here. Terraform variables will be
# substituted before the script is placed into the coder_script resource.

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

KNOWN="$HOME/.ssh/known_hosts"
touch "$KNOWN"
chmod 600 "$KNOWN"

TMP=$(mktemp) || TMP="/tmp/ssh_known_hosts.$$"
TMP2=$(mktemp) || TMP2="/tmp/ssh_known_hosts2.$$"
trap 'rm -f "$TMP" "$TMP2"' EXIT

# Add GitHub's public keys
curl -sL https://api.github.com/meta | jq -r '.ssh_keys[]' | sed 's/^/github.com /' >"$TMP" || true
cat "$KNOWN" "$TMP" | awk '!seen[$0]++' >"$KNOWN.tmp" && mv "$KNOWN.tmp" "$KNOWN" || true

# HOSTS_LINE is provided by Terraform via templatefile; it should be a
# space-separated list of host or host:port entries.
HOSTS_LINE="${HOSTS_LINE}"

for host in $HOSTS_LINE; do
  if echo "$host" | grep -q ':'; then
    h="$${host%%:*}"
    p="$${host##*:}"
  else
    h="$host"
    p=22
  fi

  if ! ssh-keygen -F "$${h}:$${p}" -f "$KNOWN" >/dev/null 2>&1; then
    if [ "$p" != "22" ]; then
      ssh-keyscan -p "$p" "$h" >>"$TMP2" 2>/dev/null || true
    else
      ssh-keyscan "$h" >>"$TMP2" 2>/dev/null || true
    fi
  fi
done

if [ -s "$TMP2" ]; then
  cat "$KNOWN" "$TMP2" | awk '!seen[$0]++' >"$KNOWN.tmp" && mv "$KNOWN.tmp" "$KNOWN" || true
fi

echo "Downloading Coder SSH key"
ssh_key_json=$(curl --request GET --url "$${CODER_AGENT_URL}api/v2/workspaceagents/me/gitsshkey" --header "Coder-Session-Token: $CODER_AGENT_TOKEN" --silent --show-error || true)

echo "$ssh_key_json" | jq -r '.public_key' > "$HOME/.ssh/coder.pub" || true
echo "$ssh_key_json" | jq -r '.private_key' > "$HOME/.ssh/coder" || true

chmod 600 "$HOME/.ssh/coder" || true
chmod 644 "$HOME/.ssh/coder.pub" || true
chown -R embold:embold "$HOME/.ssh" 2>/dev/null || true

git config --global gpg.format ssh || true
git config --global commit.gpgsign true || true
git config --global user.signingkey "$HOME/.ssh/coder" || true
