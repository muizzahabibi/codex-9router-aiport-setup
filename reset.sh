#!/usr/bin/env bash
set -euo pipefail
REPO_RAW_BASE="${REPO_RAW_BASE:-https://raw.githubusercontent.com/muizzahabibi/codex-9router-aiport-setup/main}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
curl -fsSL "$REPO_RAW_BASE/scripts/reset-codex-config-macos.sh" -o "$TMP_DIR/reset-codex-config-macos.sh"
chmod +x "$TMP_DIR/reset-codex-config-macos.sh"
exec "$TMP_DIR/reset-codex-config-macos.sh" "$@"
