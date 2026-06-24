#!/usr/bin/env bash
set -euo pipefail

CODEX_CONFIG="${CODEX_CONFIG:-$HOME/.codex/config.toml}"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

if [ ! -f "$CODEX_CONFIG" ]; then
  fail "Codex config tidak ditemukan: $CODEX_CONFIG"
fi

BACKUP="${CODEX_CONFIG}.bak.reset.$(date +%Y%m%d-%H%M%S)"
cp "$CODEX_CONFIG" "$BACKUP"
chmod 600 "$BACKUP" || true
log "Backup dibuat: $BACKUP"

python3 - "$CODEX_CONFIG" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
lines = path.read_text().splitlines()
out = []
skip_section = False
for line in lines:
    stripped = line.strip()
    if stripped.startswith('[') and stripped.endswith(']'):
        skip_section = stripped == '[model_providers.9router]'
        if skip_section:
            continue
    if skip_section:
        continue
    if stripped.startswith('model = '):
        continue
    if stripped.startswith('model_provider = '):
        continue
    out.append(line)

text = '\n'.join(out).rstrip() + '\n'
path.write_text(text)
PY
chmod 600 "$CODEX_CONFIG" || true
log "Reset selesai: model/model_provider dan [model_providers.9router] dihapus."
log "Buka Codex lagi lalu login dengan akun ChatGPT/OpenAI asli."
