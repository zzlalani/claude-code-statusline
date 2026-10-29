#!/bin/bash
# Installs this project's statusline-command.sh over the live Claude Code copy.
# Usage: bash sync.sh
set -euo pipefail

project_dir="$(cd "$(dirname "$0")" && pwd)"
source_file="$project_dir/statusline-command.sh"
target_file="${STATUSLINE_TARGET:-$HOME/.claude/statusline-command.sh}"

if [ -z "${STATUSLINE_SKIP_TESTS:-}" ]; then
  bash "$project_dir/test.sh" >/dev/null || { echo "tests failed, not syncing" >&2; exit 1; }
fi

if [ -f "$target_file" ] && cmp -s "$source_file" "$target_file"; then
  echo "already up to date: $target_file"
  exit 0
fi

[ -f "$target_file" ] && cp "$target_file" "$target_file.bak"
cp "$source_file" "$target_file"
echo "synced to $target_file (previous copy: $target_file.bak)"
