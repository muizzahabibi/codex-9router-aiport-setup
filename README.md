# Codex + 9Router + AIPort Setup

Interactive setup scripts for running Codex through a local [9Router](https://github.com/decolua/9router) instance with an AIPort OpenAI-compatible provider.

## What This Does

- Installs Node.js/npm when missing.
- Installs `9router` globally via npm when missing.
- Starts 9Router locally on `127.0.0.1:20128`.
- Configures AIPort as an OpenAI-compatible provider.
- Configures Codex to use local 9Router.
- Backs up existing Codex config before applying changes.
- Prevents duplicate provider/API key setup by updating or rotating existing entries.
- Adds autostart + autorestart:
  - macOS: LaunchAgent
  - Windows: Scheduled Task

Default provider settings:

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

Run PowerShell as a normal user:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force; iwr -UseBasicParsing https://raw.githubusercontent.com/muizzahabibi/codex-9router-aiport-setup/main/install.ps1 | iex
```

If your organization blocks `iex`, use the safer download-then-run flow:

```powershell
iwr -UseBasicParsing https://raw.githubusercontent.com/muizzahabibi/codex-9router-aiport-setup/main/scripts/setup-codex-9router-windows.ps1 -OutFile .\setup-codex-9router-windows.ps1
.\setup-codex-9router-windows.ps1
```

## macOS Manual Run

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

Before applying Codex settings, the scripts back up:

macOS/Linux-style Codex path:

```text
~/.codex/config.toml.bak.YYYYMMDD-HHMMSS
```

Windows Codex path:

```text
%USERPROFILE%\.codex\config.toml.bak.YYYYMMDD-HHMMSS
```

## Autostart Management

### macOS

Check service:

```bash
launchctl print gui/$(id -u)/id.aiport.9router
```

Stop autostart:

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
  -d '{"model":"aiport/deepseek-v4-flash","messages":[{"role":"user","content":"Jawab singkat: 2+2 berapa?"}],"max_tokens":80}'
```

## Notes

- Do not commit API keys.
- Keep the repository private if it includes internal operational instructions.
- If 9Router starts for the first time, it may take longer while preparing runtime dependencies.
