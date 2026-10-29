#!/bin/bash
# Installs the status line into Claude Code and points settings.json at it.
# Usage: bash install.sh   (or: curl -fsSL <raw install.sh url> | bash)
# Env: STATUSLINE_INSTALL_DIR (default ~/.claude), STATUSLINE_SOURCE (local file instead of download),
#      STATUSLINE_FORCE=1 (replace a different status line already configured).
set -euo pipefail

REPO_RAW_URL="https://raw.githubusercontent.com/zzlalani/claude-code-statusline/main"
install_dir="${STATUSLINE_INSTALL_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}}"
script_path="$install_dir/statusline-command.sh"
settings_path="$install_dir/settings.json"
command_line="bash $script_path"

command -v jq >/dev/null || { echo "jq is required (brew install jq)" >&2; exit 1; }

fetch_script() {
  local dest="$1"
  if [ -n "${STATUSLINE_SOURCE:-}" ]; then
    cp "$STATUSLINE_SOURCE" "$dest"
  else
    curl -fsSL "$REPO_RAW_URL/statusline-command.sh" -o "$dest"
  fi
}

current_command() {
  [ -f "$settings_path" ] && jq -r '.statusLine.command // empty' "$settings_path" || true
}

mkdir -p "$install_dir"

existing="$(current_command)"
if [ -n "$existing" ] && [ "$existing" != "$command_line" ] && [ -z "${STATUSLINE_FORCE:-}" ]; then
  echo "another status line is already configured: $existing" >&2
  echo "re-run with STATUSLINE_FORCE=1 to replace it (settings.json is backed up first)" >&2
  exit 1
fi

staged="$(mktemp)"
trap 'rm -f "$staged"' EXIT
fetch_script "$staged"

if [ -f "$script_path" ] && cmp -s "$staged" "$script_path" && [ "$existing" = "$command_line" ]; then
  echo "already installed: $script_path"
  exit 0
fi

[ -f "$script_path" ] && cp "$script_path" "$script_path.bak"
cp "$staged" "$script_path"

[ -f "$settings_path" ] && cp "$settings_path" "$settings_path.bak"
base='{}'
[ -f "$settings_path" ] && base="$(cat "$settings_path")"
echo "$base" | jq --arg cmd "$command_line" '.statusLine = {type: "command", command: $cmd}' > "$settings_path.tmp"
mv "$settings_path.tmp" "$settings_path"

echo "installed: $script_path"
echo "status line configured in $settings_path (restart Claude Code or send a message to refresh)"
