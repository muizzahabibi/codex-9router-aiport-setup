$ErrorActionPreference = 'Stop'
$RepoRawBase = if ($env:REPO_RAW_BASE) { $env:REPO_RAW_BASE.TrimEnd('/') } else { 'https://raw.githubusercontent.com/muizzahabibi/codex-9router-aiport-setup/main' }
$TempFile = Join-Path $env:TEMP 'setup-codex-9router-windows.ps1'
$CacheBust = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
Invoke-WebRequest -UseBasicParsing -Uri "$RepoRawBase/scripts/setup-codex-9router-windows.ps1?cb=$CacheBust" -OutFile $TempFile
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $TempFile
