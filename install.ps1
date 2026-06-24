$ErrorActionPreference = 'Stop'
$Repo = if ($env:GITHUB_REPO) { $env:GITHUB_REPO } else { 'muizzahabibi/codex-9router-aiport-setup' }
$Ref = if ($env:GITHUB_REF) { $env:GITHUB_REF } else { 'main' }
$TempFile = Join-Path $env:TEMP 'setup-codex-9router-windows.ps1'
$ApiUrl = "https://api.github.com/repos/$Repo/contents/scripts/setup-codex-9router-windows.ps1?ref=$Ref"
$Response = Invoke-RestMethod -Uri $ApiUrl -Headers @{ 'User-Agent' = 'codex-9router-aiport-setup' }
$Content = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($Response.content -replace '\s', '')))
Set-Content -Encoding UTF8 -Path $TempFile -Value $Content
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $TempFile
