# Codex + 9Router + AIPort Setup

Interactive setup scripts for running Codex through a local 9Router instance with an AIPort OpenAI-compatible provider.

Indonesian documentation is available in [README.md](README.md).

## What This Does

- Checks and installs Node.js/npm when missing.
- Checks and installs `9router` globally via npm when missing.
- Runs 9Router locally on `127.0.0.1:20128`.
- Configures AIPort as an OpenAI-compatible provider in 9Router.
- Configures Codex to use local 9Router.
- Backs up the Codex config before applying changes.
- Avoids duplicate provider/API key entries by updating or rotating existing entries.
- Adds autostart + autorestart:
  - macOS: LaunchAgent
  - Windows: Scheduled Task

Default settings:

| Setting | Default |
|---|---|
| AIPort base URL | `https://aiport.id/v1` |
| Model | `deepseek-v4-flash` |
| 9Router prefix | `aiport` |
| Codex model | `aiport/deepseek-v4-flash` |
| Local endpoint | `http://127.0.0.1:20128/v1` |

## macOS One-Line Install

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/muizzahabibi/codex-9router-aiport-setup/main/install.sh)"
```

The script will ask for:

- AIPort base URL
- AIPort model
- 9Router provider prefix
- AIPort API key, hidden input
- Final confirmation

## Windows One-Line Install

Run PowerShell:

```powershell
$r=Invoke-RestMethod -Uri 'https://api.github.com/repos/muizzahabibi/codex-9router-aiport-setup/contents/install.ps1?ref=main' -Headers @{'User-Agent'='codex-9router-aiport-setup'}; $s=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($r.content -replace '\s',''))); Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force; iex $s
```



If the command above still hits a cached script, use this pinned version:

```powershell
$env:GITHUB_REF='04fcb421a1bbc6c8f157c742e014e6e5d2331a59'; $r=Invoke-RestMethod -Uri "https://api.github.com/repos/muizzahabibi/codex-9router-aiport-setup/contents/install.ps1?ref=$env:GITHUB_REF" -Headers @{'User-Agent'='codex-9router-aiport-setup'}; $s=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($r.content -replace '\s',''))); Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force; iex $s
```

If your environment blocks `iex`, use the download-then-run flow:

```powershell
iwr -UseBasicParsing https://raw.githubusercontent.com/muizzahabibi/codex-9router-aiport-setup/main/scripts/setup-codex-9router-windows.ps1 -OutFile .\setup-codex-9router-windows.ps1
.\setup-codex-9router-windows.ps1
```

## Manual macOS Run

```bash
curl -fsSL https://raw.githubusercontent.com/muizzahabibi/codex-9router-aiport-setup/main/scripts/setup-codex-9router-macos.sh -o setup-codex-9router-macos.sh
chmod +x setup-codex-9router-macos.sh
./setup-codex-9router-macos.sh
```

## Non-Interactive Usage

macOS:

```bash
AIPORT_API_KEY='ak_...' \
AIPORT_BASE_URL='https://aiport.id/v1' \
AIPORT_MODEL='deepseek-v4-flash' \
AIPORT_PROVIDER_PREFIX='aiport' \
./scripts/setup-codex-9router-macos.sh
```

Windows:

```powershell
$env:AIPORT_API_KEY='ak_...'
$env:AIPORT_BASE_URL='https://aiport.id/v1'
$env:AIPORT_MODEL='deepseek-v4-flash'
$env:AIPORT_PROVIDER_PREFIX='aiport'
.\scripts\setup-codex-9router-windows.ps1
```

## Backup Location

Before changing Codex settings, the scripts back up the config file.

macOS:

```text
~/.codex/config.toml.bak.YYYYMMDD-HHMMSS
```

Windows:

```text
%USERPROFILE%\.codex\config.toml.bak.YYYYMMDD-HHMMSS
```

## Autostart Management

### macOS

Check service:

```bash
launchctl print gui/$(id -u)/id.aiport.9router
```

Disable autostart:

```bash
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/id.aiport.9router.plist
```

### Windows

Check task:

```powershell
Get-ScheduledTask -TaskName 'AIPort 9Router'
```

Stop task:

```powershell
Stop-ScheduledTask -TaskName 'AIPort 9Router'
```

Remove autostart:

```powershell
Unregister-ScheduledTask -TaskName 'AIPort 9Router' -Confirm:$false
```

## Verify

List models:

```bash
curl http://127.0.0.1:20128/v1/models
```

Test chat completion:

```bash
curl -sS http://127.0.0.1:20128/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"aiport/deepseek-v4-flash","messages":[{"role":"user","content":"Answer briefly: what is 2+2?"}],"max_tokens":80}'
```

## Notes

- If Windows shows , rerun the latest installer. The current version reloads the provider ID from 9Router before creating the API key connection.
- Do not commit API keys.
- The scripts do not store API keys in this repository; keys are only requested during setup.
- On first run, 9Router may take longer while preparing runtime dependencies.
- If model requests fail, check your AIPort balance, API key, and model name in the 9Router dashboard.
