#!/usr/bin/env bash
set -euo pipefail

REPO_RAW_BASE="${REPO_RAW_BASE:-https://raw.githubusercontent.com/muizzahabibi/codex-9router-aiport-setup/main}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

if [ "$(uname -s)" != "Darwin" ]; then
  echo "ERROR: install.sh ini untuk macOS. Untuk Windows gunakan install.ps1 dari README." >&2
  exit 1
fi

curl -fsSL "$REPO_RAW_BASE/scripts/setup-codex-9router-macos.sh" -o "$TMP_DIR/setup-codex-9router-macos.sh"
chmod +x "$TMP_DIR/setup-codex-9router-macos.sh"
exec "$TMP_DIR/setup-codex-9router-macos.sh" "$@"
