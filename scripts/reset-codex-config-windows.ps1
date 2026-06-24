$ErrorActionPreference = 'Stop'

$CodexConfig = if ($env:CODEX_CONFIG) { $env:CODEX_CONFIG } else { Join-Path $env:USERPROFILE '.codex\config.toml' }

function Write-Step([string]$Message) { Write-Host "==> $Message" -ForegroundColor Cyan }
function Fail([string]$Message) { Write-Host "ERROR: $Message" -ForegroundColor Red; exit 1 }

if (-not (Test-Path $CodexConfig)) {
  Fail "Codex config tidak ditemukan: $CodexConfig"
}

$Backup = "$CodexConfig.bak.reset.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item $CodexConfig $Backup -Force
Write-Step "Backup dibuat: $Backup"

$Lines = Get-Content $CodexConfig
$Out = New-Object System.Collections.Generic.List[string]
$SkipSection = $false
foreach ($Line in $Lines) {
  $Trimmed = $Line.Trim()
  if ($Trimmed.StartsWith('[') -and $Trimmed.EndsWith(']')) {
    $SkipSection = ($Trimmed -eq '[model_providers.9router]')
    if ($SkipSection) { continue }
  }
  if ($SkipSection) { continue }
  if ($Trimmed.StartsWith('model = ')) { continue }
  if ($Trimmed.StartsWith('model_provider = ')) { continue }
  $Out.Add($Line)
}

Set-Content -Encoding UTF8 -Path $CodexConfig -Value ($Out -join [Environment]::NewLine)
Write-Step 'Reset selesai: model/model_provider dan [model_providers.9router] dihapus.'
Write-Step 'Buka Codex lagi lalu login dengan akun ChatGPT/OpenAI asli.'
