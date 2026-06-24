#!/usr/bin/env bash
set -euo pipefail

# macOS Codex + 9Router + AIPort OpenAI-compatible setup.
# Usage interaktif:
#   ./setup-codex-9router-macos.sh
# Optional non-interaktif:
#   AIPORT_API_KEY='ak_...' AIPORT_BASE_URL='https://aiport.id/v1' AIPORT_MODEL='deepseek-v4-flash' ./setup-codex-9router-macos.sh

AIPORT_BASE_URL="${AIPORT_BASE_URL:-}"
AIPORT_MODEL="${AIPORT_MODEL:-}"
AIPORT_PROVIDER_PREFIX="${AIPORT_PROVIDER_PREFIX:-}"
NINE_ROUTER_API="${NINE_ROUTER_API:-http://127.0.0.1:20128}"
NINE_ROUTER_MODEL="${AIPORT_PROVIDER_PREFIX:-aiport}/${AIPORT_MODEL:-deepseek-v4-flash}"
NINE_ROUTER_API_KEY_NAME="${NINE_ROUTER_API_KEY_NAME:-Codex Local}"
DATA_DIR_9R="${DATA_DIR:-$HOME/.9router}"
LAUNCH_AGENT_LABEL="id.aiport.9router"
LAUNCH_AGENT_PLIST="$HOME/Library/LaunchAgents/$LAUNCH_AGENT_LABEL.plist"
LAUNCH_AGENT_LOG="$DATA_DIR_9R/launchd.log"
LAUNCH_AGENT_ERR="$DATA_DIR_9R/launchd.err"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*" >&2; }
fail() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }
command_exists() { command -v "$1" >/dev/null 2>&1; }

install_homebrew() {
  if command_exists brew; then
    log "Homebrew sudah terinstall: $(brew --version | head -n 1)"
    return
  fi
  log "Homebrew belum ada, install Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
  if [ -x /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"; fi
  command_exists brew || fail "Homebrew belum terdeteksi. Buka terminal baru lalu jalankan ulang script."
}

install_node_npm() {
  if command_exists npm; then
    log "npm sudah terinstall: $(npm --version)"
    return
  fi
  install_homebrew
  log "npm belum ada, install Node.js via Homebrew..."
  brew install node
  command_exists npm || fail "npm masih belum terdeteksi setelah install Node.js."
}

install_9router() {
  if command_exists 9router; then
    log "9Router sudah terinstall: $(command -v 9router)"
    return
  fi
  install_node_npm
  log "9Router belum ada, install global via npm..."
  npm install -g 9router
  command_exists 9router || fail "9Router gagal terinstall atau belum masuk PATH."
}

prompt_default() {
  local var_name="$1"
  local prompt_text="$2"
  local default_value="$3"
  local current_value="${!var_name:-}"
  local input=""

  if [ -n "$current_value" ]; then
    log "$prompt_text pakai dari env: $current_value"
    return
  fi

  read -r -p "$prompt_text [$default_value]: " input
  printf -v "$var_name" '%s' "${input:-$default_value}"
}

prompt_secret() {
  local var_name="$1"
  local prompt_text="$2"
  local input=""
  local current_value="${!var_name:-}"

  if [ -n "$current_value" ]; then
    log "$prompt_text sudah diisi dari env."
    return
  fi

  while [ -z "$input" ]; do
    read -r -s -p "$prompt_text: " input
    echo >&2
    if [ -z "$input" ]; then
      echo 'Input wajib diisi.' >&2
    fi
  done
  printf -v "$var_name" '%s' "$input"
}

confirm_continue() {
  local answer=""
  echo >&2
  echo "Konfirmasi setup:" >&2
  printf '  Provider prefix : %s\n' "$AIPORT_PROVIDER_PREFIX" >&2
  printf '  Base URL        : %s\n' "$AIPORT_BASE_URL" >&2
  printf '  Model           : %s\n' "$AIPORT_MODEL" >&2
  printf '  Codex model     : %s/%s\n' "$AIPORT_PROVIDER_PREFIX" "$AIPORT_MODEL" >&2
  printf '  API key         : %s...%s\n' "${AIPORT_API_KEY:0:6}" "${AIPORT_API_KEY: -4}" >&2
  read -r -p "Lanjut setup? [Y/n]: " answer
  case "$answer" in
    n|N|no|NO|No) fail "Setup dibatalkan user." ;;
  esac
}

require_inputs() {
  [ "$(uname -s)" = "Darwin" ] || fail "Script ini khusus macOS."
  prompt_default AIPORT_BASE_URL "AIPort OpenAI-compatible Base URL" "https://aiport.id/v1"
  prompt_default AIPORT_MODEL "AIPort model" "deepseek-v4-flash"
  prompt_default AIPORT_PROVIDER_PREFIX "9Router provider prefix" "aiport"
  prompt_secret AIPORT_API_KEY "Paste AIPort API key"
  NINE_ROUTER_MODEL="$AIPORT_PROVIDER_PREFIX/$AIPORT_MODEL"
  confirm_continue
}

ensure_9router_running() {
  if curl -fsS "$NINE_ROUTER_API/api/provider-nodes" >/dev/null 2>&1 || curl -fsS "$NINE_ROUTER_API/v1/models" >/dev/null 2>&1; then
    log "9Router sudah berjalan di $NINE_ROUTER_API"
    return
  fi

  log "Menjalankan 9Router background..."
  mkdir -p "$DATA_DIR_9R"
  nohup 9router --host 127.0.0.1 --port 20128 --no-browser --skip-update >/tmp/9router-setup.log 2>&1 &

  for _ in {1..120}; do
    sleep 1
    if curl -fsS "$NINE_ROUTER_API/api/provider-nodes" >/dev/null 2>&1 || curl -fsS "$NINE_ROUTER_API/v1/models" >/dev/null 2>&1; then
      log "9Router aktif di $NINE_ROUTER_API"
      return
    fi
  done
  fail "9Router belum aktif setelah 120 detik. Cek log: /tmp/9router-setup.log dan $LAUNCH_AGENT_LOG"
}

node_json_request() {
  local method="$1"
  local api_path="$2"
  local payload="${3:-}"
  NODE_PATH="$(npm root -g 2>/dev/null || true)" node - "$NINE_ROUTER_API" "$DATA_DIR_9R" "$method" "$api_path" "$payload" <<'NODE'
const http = require('http');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const os = require('os');

const [baseUrl, dataDir, method, apiPath, payloadRaw] = process.argv.slice(2);
const url = new URL(apiPath, baseUrl);
const secretFile = path.join(dataDir, 'auth', 'cli-secret');
const machineFile = path.join(dataDir, 'machine-id');
const salt = '9r-cli-auth';

function read(file) { try { return fs.readFileSync(file, 'utf8').trim(); } catch { return ''; } }
let rawMachineId = read(machineFile);
if (!rawMachineId) {
  try { rawMachineId = require('node-machine-id').machineIdSync(); }
  catch { rawMachineId = os.hostname(); }
}
let secret = read(secretFile);
if (!secret) {
  secret = crypto.randomBytes(32).toString('hex');
  try {
    fs.mkdirSync(path.dirname(secretFile), { recursive: true });
    fs.writeFileSync(secretFile, secret, { mode: 0o600 });
  } catch {}
}
const token = rawMachineId && secret
  ? crypto.createHash('sha256').update(rawMachineId + salt + secret).digest('hex').substring(0, 16)
  : '';
const body = payloadRaw ? JSON.stringify(JSON.parse(payloadRaw)) : '';

const req = http.request({
  hostname: url.hostname,
  port: url.port || 80,
  path: url.pathname + url.search,
  method,
  headers: {
    ...(body ? {'content-type': 'application/json', 'content-length': Buffer.byteLength(body)} : {}),
    ...(token ? { 'x-9r-cli-token': token } : {})
  }
}, (res) => {
  let out = '';
  res.setEncoding('utf8');
  res.on('data', chunk => out += chunk);
  res.on('end', () => {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      console.error(out || `HTTP ${res.statusCode}`);
      process.exit(1);
    }
    process.stdout.write(out);
  });
});
req.on('error', err => { console.error(err.message); process.exit(1); });
if (body) req.write(body);
req.end();
NODE
}

node_json_get() { node_json_request "GET" "$1"; }
node_json_post() { node_json_request "POST" "$1" "$2"; }
node_json_put() { node_json_request "PUT" "$1" "$2"; }
node_json_delete() { node_json_request "DELETE" "$1"; }

backup_codex_config() {
  local codex_config="$HOME/.codex/config.toml"
  if [ -f "$codex_config" ]; then
    local backup="${codex_config}.bak.$(date +%Y%m%d-%H%M%S)"
    cp "$codex_config" "$backup"
    chmod 600 "$backup"
    log "Backup Codex config dibuat: $backup"
  else
    log "Codex config belum ada, backup dilewati."
  fi
}

install_launch_agent() {
  local nine_router_bin
  nine_router_bin="$(command -v 9router)"
  [ -n "$nine_router_bin" ] || fail "Binary 9router tidak ditemukan."

  log "Memasang LaunchAgent autostart + autorestart 9Router..."
  mkdir -p "$HOME/Library/LaunchAgents" "$DATA_DIR_9R"
  if launchctl print "gui/$(id -u)/$LAUNCH_AGENT_LABEL" >/dev/null 2>&1; then
    launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENT_PLIST" >/dev/null 2>&1 || true
  fi

  cat > "$LAUNCH_AGENT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LAUNCH_AGENT_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$nine_router_bin</string>
    <string>--host</string>
    <string>127.0.0.1</string>
    <string>--port</string>
    <string>20128</string>
    <string>--no-browser</string>
    <string>--skip-update</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>10</integer>
  <key>WorkingDirectory</key><string>$HOME</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>HOME</key><string>$HOME</string>
    <key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>DATA_DIR</key><string>$DATA_DIR_9R</string>
  </dict>
  <key>StandardOutPath</key><string>$LAUNCH_AGENT_LOG</string>
  <key>StandardErrorPath</key><string>$LAUNCH_AGENT_ERR</string>
</dict>
</plist>
PLIST

  chmod 644 "$LAUNCH_AGENT_PLIST"
  launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENT_PLIST"
  launchctl enable "gui/$(id -u)/$LAUNCH_AGENT_LABEL"
  launchctl kickstart -k "gui/$(id -u)/$LAUNCH_AGENT_LABEL" || true
  log "LaunchAgent aktif: $LAUNCH_AGENT_PLIST"
}

setup_aiport_provider() {
  log "Upsert custom provider AIPort di 9Router..."
  local provider_payload nodes_response provider_id
  provider_payload=$(node -e 'console.log(JSON.stringify({name:"AIPort",prefix:process.argv[1],baseUrl:process.argv[2],type:"openai-compatible",apiType:"chat"}))' "$AIPORT_PROVIDER_PREFIX" "$AIPORT_BASE_URL")
  nodes_response=$(node_json_get "/api/provider-nodes" || printf '{}')
  provider_id=$(printf '%s' "$nodes_response" | node - "$AIPORT_PROVIDER_PREFIX" <<'NODE'
let s = '';
process.stdin.on('data', d => s += d);
process.stdin.on('end', () => {
  const prefix = process.argv[2];
  const json = JSON.parse(s || '{}');
  const list = json?.data?.nodes || json?.data?.providerNodes || json?.data || json?.nodes || [];
  const arr = Array.isArray(list) ? list : Object.values(list || {});
  const found = arr.find(n => n?.prefix === prefix || n?.id === prefix || n?.data?.prefix === prefix);
  process.stdout.write(found?.id || found?.data?.id || '');
});
NODE
)

  if [ -n "$provider_id" ]; then
    log "Provider '$AIPORT_PROVIDER_PREFIX' sudah ada, update config provider."
    node_json_put "/api/provider-nodes/$provider_id" "$provider_payload" >/tmp/9router-provider.json
  else
    log "Provider '$AIPORT_PROVIDER_PREFIX' belum ada, buat baru."
    node_json_post "/api/provider-nodes" "$provider_payload" >/tmp/9router-provider.json
    provider_id=$(node -e 'const fs=require("fs"); const j=JSON.parse(fs.readFileSync("/tmp/9router-provider.json","utf8")||"{}"); console.log(j?.data?.node?.id || j?.data?.id || j?.node?.id || j?.id || process.argv[1])' "$AIPORT_PROVIDER_PREFIX")
  fi

  log "Upsert koneksi API key AIPort di 9Router..."
  local providers_response connection_id key_payload
  providers_response=$(node_json_get "/api/providers" || printf '{}')
  connection_id=$(printf '%s' "$providers_response" | node - "$AIPORT_PROVIDER_PREFIX" "$provider_id" <<'NODE'
let s = '';
process.stdin.on('data', d => s += d);
process.stdin.on('end', () => {
  const prefix = process.argv[2];
  const providerId = process.argv[3];
  const json = JSON.parse(s || '{}');
  const list = json?.data?.connections || json?.data?.providers || json?.data || json?.connections || [];
  const arr = Array.isArray(list) ? list : Object.values(list || {});
  const found = arr.find(c => {
    const provider = c?.provider || c?.providerId || c?.data?.provider || c?.data?.providerId;
    const name = c?.name || c?.data?.name || '';
    return (provider === prefix || provider === providerId) && /AIPort/i.test(name);
  });
  process.stdout.write(found?.id || found?.data?.id || '');
});
NODE
)
  if [ -n "$connection_id" ]; then
    log "Koneksi AIPort lama ditemukan, hapus dulu agar tidak dobel dan key terbaru aktif."
    node_json_delete "/api/providers/$connection_id" >/tmp/9router-connection-delete.json || true
  fi

  key_payload=$(node -e 'console.log(JSON.stringify({provider:process.argv[1],name:"AIPort API Key",apiKey:process.argv[2]}))' "$provider_id" "$AIPORT_API_KEY")
  node_json_post "/api/providers" "$key_payload" >/tmp/9router-connection.json
}

create_9router_api_key() {
  log "Menyiapkan API key lokal 9Router untuk Codex..."
  local keys_response key_id key_response key_value
  keys_response=$(node_json_get "/api/keys" || printf '{}')
  key_id=$(printf '%s' "$keys_response" | node - "$NINE_ROUTER_API_KEY_NAME" <<'NODE'
let s = '';
process.stdin.on('data', d => s += d);
process.stdin.on('end', () => {
  const name = process.argv[2];
  const json = JSON.parse(s || '{}');
  const list = json?.data?.keys || json?.data || json?.keys || [];
  const arr = Array.isArray(list) ? list : Object.values(list || {});
  const found = arr.find(k => (k?.name || k?.data?.name) === name);
  process.stdout.write(found?.id || found?.data?.id || '');
});
NODE
)

  if [ -n "$key_id" ]; then
    log "API key lokal 9Router lama ditemukan, rotasi agar tidak dobel."
    node_json_delete "/api/keys/$key_id" >/tmp/9router-api-key-delete.json || true
  fi

  key_response=$(node_json_post "/api/keys" "{\"name\":\"$NINE_ROUTER_API_KEY_NAME\"}")
  key_value=$(printf '%s' "$key_response" | node -e 'let s=""; process.stdin.on("data",d=>s+=d); process.stdin.on("end",()=>{const j=JSON.parse(s); console.log(j?.data?.key || j?.key || j?.data?.apiKey || "")})')
  [ -n "$key_value" ] || fail "Gagal mengambil API key 9Router dari respons: $key_response"
  printf '%s' "$key_value"
}

apply_codex_settings() {
  local router_key="$1"
  log "Apply setting Codex via 9Router API..."
  local payload
  payload=$(node -e 'console.log(JSON.stringify({baseUrl:process.argv[1] + "/v1",apiKey:process.argv[2],model:process.argv[3]}))' "$NINE_ROUTER_API" "$router_key" "$NINE_ROUTER_MODEL")
  node_json_post "/api/cli-tools/codex-settings" "$payload" >/tmp/9router-codex-settings.json
}

main() {
  require_inputs
  install_node_npm
  install_9router
  install_launch_agent
  ensure_9router_running
  setup_aiport_provider
  router_key=$(create_9router_api_key)
  backup_codex_config
  apply_codex_settings "$router_key"

  cat <<DONE

Selesai.

Yang sudah diset:
  - 9Router: $NINE_ROUTER_API
  - Codex base_url: $NINE_ROUTER_API/v1
  - Codex model: $NINE_ROUTER_MODEL
  - Upstream provider: $AIPORT_BASE_URL
  - LaunchAgent: $LAUNCH_AGENT_PLIST
  - Log autostart: $LAUNCH_AGENT_LOG
  - Error log: $LAUNCH_AGENT_ERR
  - Backup Codex config: ~/.codex/config.toml.bak.YYYYMMDD-HHMMSS

Coba jalankan:
  codex

9Router juga sudah dibuat auto-start saat login dan auto-restart jika proses mati.

Cek service:
  launchctl print gui/$(id -u)/$LAUNCH_AGENT_LABEL

Stop permanen kalau perlu:
  launchctl bootout gui/$(id -u) $LAUNCH_AGENT_PLIST

Kalau model belum muncul, buka dashboard:
  $NINE_ROUTER_API/dashboard
DONE
}

main "$@"
