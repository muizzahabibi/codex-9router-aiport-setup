# Windows Codex + 9Router + AIPort OpenAI-compatible setup.
# Run in PowerShell:
#   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
#   .\setup-codex-9router-windows.ps1

$ErrorActionPreference = 'Stop'

$DefaultAIPortBaseUrl = 'https://aiport.id/v1'
$DefaultAIPortModel = 'deepseek-v4-flash'
$DefaultProviderPrefix = 'aiport'
$NineRouterApi = if ($env:NINE_ROUTER_API) { $env:NINE_ROUTER_API.TrimEnd('/') } else { 'http://127.0.0.1:20128' }
$TaskName = 'AIPort 9Router'
$TaskScriptDir = Join-Path $env:APPDATA '9router'
$TaskScriptPath = Join-Path $TaskScriptDir 'start-9router.ps1'
$CodexConfig = Join-Path $env:USERPROFILE '.codex\config.toml'
$DataDir9R = if ($env:DATA_DIR) { $env:DATA_DIR } else { Join-Path $env:APPDATA '9router' }

function Write-Step([string]$Message) {
  Write-Host "==> $Message" -ForegroundColor Cyan
}

function Fail([string]$Message) {
  Write-Host "ERROR: $Message" -ForegroundColor Red
  exit 1
}

function Prompt-Default([string]$Label, [string]$DefaultValue, [string]$EnvValue = '') {
  if (-not [string]::IsNullOrWhiteSpace($EnvValue)) {
    Write-Step "$Label pakai dari env: $EnvValue"
    return $EnvValue
  }
  $InputValue = Read-Host "$Label [$DefaultValue]"
  if ([string]::IsNullOrWhiteSpace($InputValue)) { return $DefaultValue }
  return $InputValue.Trim()
}

function Prompt-Secret([string]$Label, [string]$EnvValue = '') {
  if (-not [string]::IsNullOrWhiteSpace($EnvValue)) {
    Write-Step "$Label sudah diisi dari env."
    return $EnvValue
  }
  while ($true) {
    $Secure = Read-Host $Label -AsSecureString
    $Plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure))
    if (-not [string]::IsNullOrWhiteSpace($Plain)) { return $Plain.Trim() }
    Write-Host 'Input wajib diisi.' -ForegroundColor Yellow
  }
}

function Get-CommandPath([string]$Name) {
  $Cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if ($Cmd) { return $Cmd.Source }
  return $null
}

function Ensure-Npm {
  $Npm = Get-CommandPath 'npm.cmd'
  if (-not $Npm) { $Npm = Get-CommandPath 'npm' }
  if ($Npm) {
    Write-Step "npm sudah terinstall: $(npm --version)"
    return
  }

  $Winget = Get-CommandPath 'winget.exe'
  if (-not $Winget) {
    Fail 'npm belum ada dan winget tidak ditemukan. Install Node.js LTS dari https://nodejs.org lalu jalankan ulang script.'
  }

  Write-Step 'npm belum ada, install Node.js LTS via winget...'
  winget install --id OpenJS.NodeJS.LTS --exact --accept-package-agreements --accept-source-agreements
  $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
  if (-not (Get-CommandPath 'npm.cmd') -and -not (Get-CommandPath 'npm')) {
    Fail 'npm masih belum terdeteksi setelah install Node.js. Buka PowerShell baru lalu jalankan ulang script.'
  }
}

function Ensure-9Router {
  $NineRouter = Get-CommandPath '9router.cmd'
  if (-not $NineRouter) { $NineRouter = Get-CommandPath '9router' }
  if ($NineRouter) {
    Write-Step "9Router sudah terinstall: $NineRouter"
    return
  }

  Ensure-Npm
  Write-Step '9Router belum ada, install global via npm...'
  npm install -g 9router
  $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
  if (-not (Get-CommandPath '9router.cmd') -and -not (Get-CommandPath '9router')) {
    Fail '9Router gagal terinstall atau belum masuk PATH. Buka PowerShell baru lalu jalankan ulang script.'
  }
}

function Install-9RouterScheduledTask {
  $NineRouter = Get-CommandPath '9router.cmd'
  if (-not $NineRouter) { $NineRouter = Get-CommandPath '9router' }
  if (-not $NineRouter) { Fail 'Binary 9router tidak ditemukan.' }

  Write-Step 'Memasang Scheduled Task autostart + autorestart 9Router...'
  New-Item -ItemType Directory -Force -Path $TaskScriptDir | Out-Null

  @"
`$ErrorActionPreference = 'SilentlyContinue'
while (`$true) {
  & '$NineRouter' --host 127.0.0.1 --port 20128 --no-browser --skip-update
  Start-Sleep -Seconds 10
}
"@ | Set-Content -Encoding UTF8 -Path $TaskScriptPath

  $Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$TaskScriptPath`""
  $Trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
  $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew
  Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Description 'Auto-start and restart 9Router for Codex/AIPort' -Force | Out-Null
  Start-ScheduledTask -TaskName $TaskName
  Write-Step "Scheduled Task aktif: $TaskName"
}

function Ensure-9RouterRunning {
  try {
    Invoke-RestMethod -Uri "$NineRouterApi/v1/models" -TimeoutSec 3 | Out-Null
    Write-Step "9Router sudah berjalan di $NineRouterApi"
    return
  } catch {}

  Write-Step 'Menunggu 9Router aktif...'
  for ($i = 1; $i -le 120; $i++) {
    try {
      Invoke-RestMethod -Uri "$NineRouterApi/v1/models" -TimeoutSec 3 | Out-Null
      Write-Step "9Router aktif di $NineRouterApi"
      return
    } catch {
      Start-Sleep -Seconds 1
    }
  }
  Fail "9Router belum aktif setelah 120 detik. Cek task '$TaskName' di Task Scheduler."
}

function Invoke-9RouterApi([string]$Method, [string]$Path, [object]$Body = $null) {
  $NodeCode = @'
const http = require('http');
const https = require('https');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const os = require('os');

const [baseUrl, dataDir, method, apiPath, payloadBase64] = process.argv.slice(2);
const url = new URL(apiPath, baseUrl);
const secretFile = path.join(dataDir, 'auth', 'cli-secret');
const machineFile = path.join(dataDir, 'machine-id');
const salt = '9r-cli-auth';
function read(file) { try { return fs.readFileSync(file, 'utf8').trim(); } catch { return ''; } }
let rawMachineId = read(machineFile) || os.hostname();
let secret = read(secretFile);
if (!secret) {
  secret = crypto.randomBytes(32).toString('hex');
  try { fs.mkdirSync(path.dirname(secretFile), { recursive: true }); fs.writeFileSync(secretFile, secret, { mode: 0o600 }); } catch {}
}
const token = rawMachineId && secret ? crypto.createHash('sha256').update(rawMachineId + salt + secret).digest('hex').substring(0, 16) : '';
const payloadRaw = payloadBase64 ? Buffer.from(payloadBase64, 'base64').toString('utf8') : '';
const body = payloadRaw ? JSON.stringify(JSON.parse(payloadRaw)) : '';
const lib = url.protocol === 'https:' ? https : http;
const req = lib.request({
  hostname: url.hostname,
  port: url.port || (url.protocol === 'https:' ? 443 : 80),
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
    if (res.statusCode < 200 || res.statusCode >= 300) { console.error(out || `HTTP ${res.statusCode}`); process.exit(1); }
    process.stdout.write(out);
  });
});
req.on('error', err => { console.error(err.message); process.exit(1); });
if (body) req.write(body);
req.end();
'@
  $Payload = if ($null -ne $Body) { $Body | ConvertTo-Json -Depth 20 -Compress } else { '' }
  $PayloadBase64 = if ($Payload) { [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Payload)) } else { '' }
  $TempJs = [IO.Path]::GetTempFileName() + '.js'
  Set-Content -Encoding UTF8 -Path $TempJs -Value $NodeCode
  try {
    $Output = node $TempJs $NineRouterApi $DataDir9R $Method $Path $PayloadBase64 2>&1
    if ($LASTEXITCODE -ne 0) { throw ($Output -join [Environment]::NewLine) }
    if ([string]::IsNullOrWhiteSpace($Output)) { return $null }
    $Parsed = $Output | ConvertFrom-Json
    if ($Parsed.error) { throw $Parsed.error }
    return $Parsed
  } finally {
    Remove-Item $TempJs -Force -ErrorAction SilentlyContinue
  }
}

function Backup-CodexConfig {
  if (Test-Path $CodexConfig) {
    $Backup = "$CodexConfig.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $CodexConfig $Backup -Force
    Write-Step "Backup Codex config dibuat: $Backup"
  } else {
    Write-Step 'Codex config belum ada, backup dilewati.'
  }
}


function Get-ProviderNodeId([string]$Prefix) {
  $Nodes = Invoke-9RouterApi GET '/api/provider-nodes'
  $Candidates = @()
  if ($Nodes.data.nodes) { $Candidates += @($Nodes.data.nodes) }
  if ($Nodes.data.providerNodes) { $Candidates += @($Nodes.data.providerNodes) }
  if ($Nodes.nodes) { $Candidates += @($Nodes.nodes) }
  if ($Nodes.data -and ($Nodes.data -is [array])) { $Candidates += @($Nodes.data) }
  foreach ($Node in $Candidates) {
    if (-not $Node) { continue }
    $NodePrefix = if ($Node.prefix) { $Node.prefix } elseif ($Node.data.prefix) { $Node.data.prefix } else { $null }
    if (($NodePrefix -eq $Prefix) -or ($Node.id -eq $Prefix)) {
      if ($Node.id) { return $Node.id }
      if ($Node.data.id) { return $Node.data.id }
    }
  }
  return $null
}

function Setup-AIPortProvider {
  param([string]$BaseUrl, [string]$Model, [string]$Prefix, [string]$ApiKey)

  Write-Step 'Upsert custom provider AIPort di 9Router...'
  $ProviderPayload = @{ name = 'AIPort'; prefix = $Prefix; baseUrl = $BaseUrl; type = 'openai-compatible'; apiType = 'chat' }
  $ProviderId = Get-ProviderNodeId $Prefix

  if ($ProviderId) {
    Write-Step "Provider '$Prefix' sudah ada, update config provider."
    Invoke-9RouterApi PUT "/api/provider-nodes/$ProviderId" $ProviderPayload | Out-Null
  } else {
    Write-Step "Provider '$Prefix' belum ada, buat baru."
    Invoke-9RouterApi POST '/api/provider-nodes' $ProviderPayload | Out-Null
  }

  Start-Sleep -Seconds 1
  $ProviderId = Get-ProviderNodeId $Prefix
  if (-not $ProviderId) {
    Fail "Provider '$Prefix' tidak ditemukan setelah create/update. Buka dashboard 9Router dan cek Custom Providers."
  }
  Write-Step "Provider aktif: $ProviderId"

  Write-Step 'Upsert koneksi API key AIPort di 9Router...'
  $Providers = Invoke-9RouterApi GET '/api/providers'
  $ConnectionList = @()
  if ($Providers.data.connections) { $ConnectionList += @($Providers.data.connections) }
  if ($Providers.data.providers) { $ConnectionList += @($Providers.data.providers) }
  if ($Providers.connections) { $ConnectionList += @($Providers.connections) }
  if ($Providers.data -and ($Providers.data -is [array])) { $ConnectionList += @($Providers.data) }

  $ExistingConnection = $ConnectionList | Where-Object {
    $_ -and (($_.provider -eq $Prefix) -or ($_.providerId -eq $Prefix) -or ($_.provider -eq $ProviderId) -or ($_.providerId -eq $ProviderId) -or ($_.data.provider -eq $ProviderId)) -and (($_.name -match 'AIPort') -or ($_.data.name -match 'AIPort'))
  } | Select-Object -First 1
  if ($ExistingConnection) {
    $ConnectionId = if ($ExistingConnection.id) { $ExistingConnection.id } else { $ExistingConnection.data.id }
    Write-Step 'Koneksi AIPort lama ditemukan, hapus dulu agar tidak dobel dan key terbaru aktif.'
    try { Invoke-9RouterApi DELETE "/api/providers/$ConnectionId" | Out-Null } catch {}
  }

  try {
    Invoke-9RouterApi POST '/api/providers' @{ provider = $ProviderId; name = 'AIPort API Key'; apiKey = $ApiKey } | Out-Null
  } catch {
    Write-Host "WARN: Koneksi pakai provider id gagal, coba fallback prefix '$Prefix'." -ForegroundColor Yellow
    Invoke-9RouterApi POST '/api/providers' @{ provider = $Prefix; name = 'AIPort API Key'; apiKey = $ApiKey } | Out-Null
  }
}

function New-9RouterApiKeyForCodex {
  Write-Step 'Menyiapkan API key lokal 9Router untuk Codex...'
  $Keys = Invoke-9RouterApi GET '/api/keys'
  $KeyList = @($Keys.data.keys) + @($Keys.keys)
  $ExistingKey = $KeyList | Where-Object { $_ -and $_.name -eq 'Codex Local' } | Select-Object -First 1
  if ($ExistingKey) {
    $KeyId = if ($ExistingKey.id) { $ExistingKey.id } else { $ExistingKey.data.id }
    Write-Step 'API key lokal 9Router lama ditemukan, rotasi agar tidak dobel.'
    try { Invoke-9RouterApi DELETE "/api/keys/$KeyId" | Out-Null } catch {}
  }
  $Created = Invoke-9RouterApi POST '/api/keys' @{ name = 'Codex Local' }
  if ($Created.data.key) { return $Created.data.key }
  if ($Created.key) { return $Created.key }
  if ($Created.data.apiKey) { return $Created.data.apiKey }
  Fail 'Gagal membuat API key lokal 9Router untuk Codex.'
}

function Apply-CodexSettings([string]$RouterKey, [string]$ModelName) {
  Write-Step 'Apply setting Codex via 9Router API...'
  Invoke-9RouterApi POST '/api/cli-tools/codex-settings' @{ baseUrl = "$NineRouterApi/v1"; apiKey = $RouterKey; model = $ModelName } | Out-Null
}

function Test-Model([string]$ModelName) {
  Write-Step "Tes koneksi model $ModelName..."
  try {
    $Body = @{ model = $ModelName; messages = @(@{ role = 'user'; content = 'Jawab singkat: 2+2 berapa?' }); max_tokens = 80 } | ConvertTo-Json -Depth 10
    $Resp = Invoke-RestMethod -Uri "$NineRouterApi/v1/chat/completions" -Method POST -ContentType 'application/json' -Body $Body -TimeoutSec 90
    $Content = $Resp.choices[0].message.content
    Write-Step "Tes sukses. Jawaban model: $Content"
  } catch {
    Write-Host "WARN: Tes model gagal: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host 'Setup tetap selesai; cek saldo/key/model di dashboard 9Router jika perlu.' -ForegroundColor Yellow
  }
}

$AIPortBaseUrl = Prompt-Default 'AIPort OpenAI-compatible Base URL' $DefaultAIPortBaseUrl $env:AIPORT_BASE_URL
$AIPortModel = Prompt-Default 'AIPort model' $DefaultAIPortModel $env:AIPORT_MODEL
$ProviderPrefix = Prompt-Default '9Router provider prefix' $DefaultProviderPrefix $env:AIPORT_PROVIDER_PREFIX
$AIPortApiKey = Prompt-Secret 'Paste AIPort API key' $env:AIPORT_API_KEY
$NineRouterModel = "$ProviderPrefix/$AIPortModel"

Write-Host ''
Write-Host 'Konfirmasi setup:'
Write-Host "  Provider prefix : $ProviderPrefix"
Write-Host "  Base URL        : $AIPortBaseUrl"
Write-Host "  Model           : $AIPortModel"
Write-Host "  Codex model     : $NineRouterModel"
Write-Host "  API key         : $($AIPortApiKey.Substring(0, [Math]::Min(6, $AIPortApiKey.Length)))...$($AIPortApiKey.Substring([Math]::Max(0, $AIPortApiKey.Length - 4)))"
$Confirm = Read-Host 'Lanjut setup? [Y/n]'
if ($Confirm -match '^(n|no)$') { Fail 'Setup dibatalkan user.' }

Ensure-Npm
Ensure-9Router
Install-9RouterScheduledTask
Ensure-9RouterRunning
Setup-AIPortProvider -BaseUrl $AIPortBaseUrl -Model $AIPortModel -Prefix $ProviderPrefix -ApiKey $AIPortApiKey
$RouterKey = New-9RouterApiKeyForCodex
Backup-CodexConfig
Apply-CodexSettings -RouterKey $RouterKey -ModelName $NineRouterModel
Test-Model -ModelName $NineRouterModel

Write-Host ''
Write-Host 'Selesai.' -ForegroundColor Green
Write-Host "  9Router       : $NineRouterApi"
Write-Host "  Codex baseUrl : $NineRouterApi/v1"
Write-Host "  Codex model   : $NineRouterModel"
Write-Host "  ScheduledTask : $TaskName"
Write-Host "  Dashboard     : $NineRouterApi/dashboard"
