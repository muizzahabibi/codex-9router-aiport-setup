# Setup Codex + 9Router + AIPort

Script interaktif untuk menjalankan Codex lewat 9Router lokal dengan provider AIPort yang kompatibel OpenAI API.

Versi English tersedia di [README_EN.md](README_EN.md).

## Fungsi Script

- Cek dan install Node.js/npm jika belum ada.
- Cek dan install `9router` global via npm jika belum ada.
- Menjalankan 9Router lokal di `127.0.0.1:20128`.
- Setup AIPort sebagai provider OpenAI-compatible di 9Router.
- Setup Codex agar memakai 9Router lokal.
- Backup config Codex sebelum diganti.
- Mencegah provider/API key dobel dengan pola update/rotasi.
- Menambahkan autostart + autorestart:
  - macOS: LaunchAgent
  - Windows: Scheduled Task

Default konfigurasi:

| Setting | Default |
|---|---|
| AIPort base URL | `https://aiport.id/v1` |
| Model | `deepseek-v4-flash` |
| Prefix 9Router | `aiport` |
| Model Codex | `aiport/deepseek-v4-flash` |
| Endpoint lokal | `http://127.0.0.1:20128/v1` |

## Install macOS Satu Baris

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/muizzahabibi/codex-9router-aiport-setup/main/install.sh)"
```

Script akan meminta input:

- AIPort base URL
- Model AIPort
- Prefix provider 9Router
- API key AIPort, input tersembunyi
- Konfirmasi sebelum setup dijalankan

## Install Windows Satu Baris

Jalankan di PowerShell:

```powershell
$r=Invoke-RestMethod -Uri 'https://api.github.com/repos/muizzahabibi/codex-9router-aiport-setup/contents/install.ps1?ref=main' -Headers @{'User-Agent'='codex-9router-aiport-setup'}; $s=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($r.content -replace '\s',''))); Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force; iex $s
```

Jika command di atas masih kena cache, pakai versi pinned ini:

```powershell
$env:GITHUB_REF='170cf3ea1df2b99952cbd46aee0635a555e1e585'; $r=Invoke-RestMethod -Uri "https://api.github.com/repos/muizzahabibi/codex-9router-aiport-setup/contents/install.ps1?ref=$env:GITHUB_REF" -Headers @{'User-Agent'='codex-9router-aiport-setup'}; $s=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($r.content -replace '\s',''))); Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force; iex $s
```

Jika `iex` diblokir oleh kebijakan keamanan, gunakan cara download lalu jalankan:

```powershell
iwr -UseBasicParsing https://raw.githubusercontent.com/muizzahabibi/codex-9router-aiport-setup/main/scripts/setup-codex-9router-windows.ps1 -OutFile .\setup-codex-9router-windows.ps1
.\setup-codex-9router-windows.ps1
```

## Jalankan Manual di macOS

```bash
curl -fsSL https://raw.githubusercontent.com/muizzahabibi/codex-9router-aiport-setup/main/scripts/setup-codex-9router-macos.sh -o setup-codex-9router-macos.sh
chmod +x setup-codex-9router-macos.sh
./setup-codex-9router-macos.sh
```

## Mode Non-Interaktif

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

## Lokasi Backup Config

Sebelum mengubah setting Codex, script akan backup file config.

macOS:

```text
~/.codex/config.toml.bak.YYYYMMDD-HHMMSS
```

Windows:

```text
%USERPROFILE%\.codex\config.toml.bak.YYYYMMDD-HHMMSS
```

## Kelola Autostart

### macOS

Cek service:

```bash
launchctl print gui/$(id -u)/id.aiport.9router
```

Matikan autostart:

```bash
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/id.aiport.9router.plist
```

### Windows

Cek task:

```powershell
Get-ScheduledTask -TaskName 'AIPort 9Router'
```

Stop task:

```powershell
Stop-ScheduledTask -TaskName 'AIPort 9Router'
```

Hapus autostart:

```powershell
Unregister-ScheduledTask -TaskName 'AIPort 9Router' -Confirm:$false
```

## Verifikasi

Cek daftar model:

```bash
curl http://127.0.0.1:20128/v1/models
```

Tes chat completion:

```bash
curl -sS http://127.0.0.1:20128/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"aiport/deepseek-v4-flash","messages":[{"role":"user","content":"Jawab singkat: 2+2 berapa?"}],"max_tokens":80}'
```

## Catatan

- Jangan commit API key.
- Script ini tidak menyimpan API key di repo; key hanya diminta saat setup.
- Saat pertama kali dijalankan, 9Router bisa butuh waktu lebih lama karena menyiapkan dependency runtime.
- Jika request model gagal, cek saldo AIPort, API key, dan nama model di dashboard 9Router.
