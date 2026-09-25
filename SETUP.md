# Setup

This repo bundles [whatsapp-mcp](https://github.com/verygoodplugins/whatsapp-mcp)
(vendored under `whatsapp-mcp/`) together with a setup script, a launchd
service, and a Claude Desktop Project configuration that turns the raw
WhatsApp MCP tools into a Classify / Digest / Act assistant. Everything is in
this one repo — a single `git clone` gets all of it. See
[`docs/superpowers/specs/2026-07-04-whatsapp-assistant-design.md`](docs/superpowers/specs/2026-07-04-whatsapp-assistant-design.md)
for the design behind this.

> The `whatsapp-mcp/` code is vendored (copied in), not a git submodule or
> live clone — it won't pick up upstream updates via `git pull`. To update it,
> re-fetch upstream and copy over `whatsapp-bridge/` and
> `whatsapp-mcp-server/` by hand (see "Updating" below).

Two people may be involved: an **operator** (technical, does most of this)
and an **end user** (only does the steps marked 🙋).

> **On Windows?** Steps 1, 2, 4, 5, 6, and 7 below are identical. Steps 3
> and the autorun/updating/troubleshooting sections differ — jump to
> [Windows setup](#windows-setup) for the PowerShell equivalents, or read
> both in parallel; each is called out inline.

## Prerequisites

- Go 1.24+
- Python 3.11+ and [`uv`](https://docs.astral.sh/uv/)
- Claude Desktop
- (optional, for sending/converting voice notes) `ffmpeg`
  — macOS: `brew install ffmpeg`; Windows: `winget install ffmpeg` (or
  `choco install ffmpeg`)
- **Windows only:** a C compiler on `PATH`, e.g. from
  [MSYS2](https://www.msys2.org/) (`pacman -S mingw-w64-x86_64-gcc`). The
  bridge's SQLite driver (`go-sqlite3`) uses cgo, so `go build`/`go run`
  needs a working `gcc` — without it the build fails with a linker error,
  not a missing-Go error.

## 1. Clone this repo

```bash
git clone <this-repo-url>
cd <this-repo>
```

That's it — `whatsapp-mcp/` is already in here.

## 2. First run — pair with WhatsApp (🙋 needs the end user's phone)

```bash
cd whatsapp-mcp/whatsapp-bridge
go run .
```

A QR code prints in the terminal. On the phone that owns the WhatsApp
account: **Settings → Linked Devices → Link a Device**, scan it. Leave this
running until you see it connect, then `Ctrl+C` it — the next step hands it
off to a background service.

## 3. Install the bridge as a background service (operator)

**macOS:**
```bash
cd ..   # back to whatsapp-mcp/
./scripts/install-launchd-macos.sh
```

This is upstream's own installer: it builds the bridge binary, installs a
launchd job so it restarts automatically on login/crash, and installs a
second launchd job that checks bridge health every 60s and sends a macOS
notification if it goes down or needs re-linking. No terminal required
afterward. To remove both later: `./scripts/uninstall-launchd-macos.sh`.

Verify:
```bash
launchctl list | grep com.whatsapp-mcp   # both bridge and bridge-monitor should show a PID
tail -20 ~/Library/Logs/whatsapp-mcp/bridge.out.log   # should show connected/ready, no crash loop
```

**Windows:** see [Windows setup](#windows-setup) — the equivalent is
`scripts\install-windows.ps1`, which registers two Scheduled Tasks instead
of launchd jobs.

## 4. Configure Claude Desktop (operator, or 🙋 if comfortable pasting JSON)

**macOS:** edit `~/Library/Application Support/Claude/claude_desktop_config.json`.
**Windows:** edit `%APPDATA%\Claude\claude_desktop_config.json` (i.e.
`C:\Users\<you>\AppData\Roaming\Claude\claude_desktop_config.json`).

```json
{
  "mcpServers": {
    "whatsapp": {
      "command": "uv",
      "args": ["--directory", "/absolute/path/to/whatsapp-mcp/whatsapp-mcp-server", "run", "main.py"]
    }
  }
}
```

On Windows, use a Windows-style absolute path (either double backslashes or
forward slashes both work in JSON), e.g.
`"C:\\Users\\you\\whatsapp-assistant\\whatsapp-mcp\\whatsapp-mcp-server"`.

Replace the path with the real absolute path on this machine, then fully
quit Claude Desktop and reopen it (macOS: Cmd+Q; Windows: right-click the
tray icon and Quit, or End Task in Task Manager if it doesn't have a tray
icon on your version).

## 5. Verify the raw connection works

In Claude Desktop, ask:
- "List my WhatsApp chats"
- "Search my WhatsApp contacts for [a name you know]"

If either fails, stop here and fix it before continuing — nothing past this
point works without this.

## 6. Create the Claude Desktop Project (operator)

1. Create a new Project in Claude Desktop.
2. Paste the contents of [`docs/whatsapp-project-instructions.md`](docs/whatsapp-project-instructions.md)
   (everything after the `---`) into the Project's custom instructions.
3. Add all three of these as knowledge files in the Project:
   - [`docs/whatsapp-profile.md`](docs/whatsapp-profile.md)
   - [`docs/whatsapp-classification.md`](docs/whatsapp-classification.md)
   - [`docs/whatsapp-reminders.md`](docs/whatsapp-reminders.md)
4. Turn on Memory for the Project: Settings → Capabilities → Memory. Without
   this, the assistant won't build up behavioral notes over time.

## 7. First conversation (🙋 end user, in the new Project)

Just say "set me up." The assistant runs a one-time guided interview — who you
are, working hours, languages, reply style, which chats it may read, and your
morning routine — then hands back filled-in versions of the knowledge files.
**Paste each one back into the Project as the replacement knowledge file to
save it** (the assistant will remind you; nothing saves on its own).

From then on, just talk: "what's new today," "help me reply to Yash," "remind
me to call Jiju Friday," "mute the Nifty group for a week," "am I set up
right." See `docs/whatsapp-project-instructions.md` for everything it can do.

## Autorun (how the background service behaves)

After step 3, the bridge runs as a launchd service (macOS) or a Scheduled
Task (Windows):
- **Close the lid / sleep:** keeps running, resumes on wake.
- **Shut down / restart:** auto-starts again when you log in.
- **Crash:** restarts itself.

**macOS** — disable: `cd whatsapp-mcp && ./scripts/uninstall-launchd-macos.sh`.
Re-enable: `./scripts/install-launchd-macos.sh`.

**Windows** — disable: `cd whatsapp-mcp && powershell -File scripts\uninstall-windows.ps1`.
Re-enable: `powershell -File scripts\install-windows.ps1`.

You can also just ask the assistant ("turn off morning auto-start") and
it'll give you the right command for your OS.

## Windows setup

Windows equivalents of the macOS-only pieces in steps 3 and above. Run
these from PowerShell **as Administrator** — the tasks themselves run as
your regular user account day-to-day, but *registering* a Scheduled Task
(`Register-ScheduledTask`) requires an elevated PowerShell session
regardless of what privilege level the task runs at once triggered.

**Install the bridge as a background task** (equivalent of step 3):
```powershell
cd whatsapp-mcp
powershell -ExecutionPolicy Bypass -File scripts\install-windows.ps1
```
This builds the bridge binary (`whatsapp-bridge.exe`) if Go is available,
writes a small env file and two generated runner scripts under
`%LOCALAPPDATA%\whatsapp-mcp\`, and registers two Scheduled Tasks:
- `WhatsAppMCPBridge` — runs the bridge at logon, auto-restarts on crash
- `WhatsAppMCPBridgeMonitor` — runs every 60s, logs (and best-effort
  toast-notifies, if the [BurntToast](https://www.powershellgallery.com/packages/BurntToast)
  module is installed) when the bridge is down, unreachable, or needs
  re-linking

These support files (env/runner scripts, state markers, logs) are tiny
(KBs) and default to `%LOCALAPPDATA%` (on your `C:` drive). If `C:` is low
on space, redirect them elsewhere with `WHATSAPP_MCP_SUPPORT_DIR` (set it
before running both the installer and uninstaller, so they agree on where
to look):
```powershell
$env:WHATSAPP_MCP_SUPPORT_DIR = "F:\path\to\whatsapp-mcp-support"
powershell -ExecutionPolicy Bypass -File scripts\install-windows.ps1
```
This only affects config/logs — your actual chat data always lives under
`whatsapp-bridge\store\` inside the repo itself, wherever you cloned it.

To remove both later:
```powershell
powershell -ExecutionPolicy Bypass -File scripts\uninstall-windows.ps1
```

Verify:
```powershell
Get-ScheduledTask -TaskName WhatsAppMCPBridge, WhatsAppMCPBridgeMonitor   # both should show State: Running/Ready
Get-Content "$env:LOCALAPPDATA\whatsapp-mcp\logs\bridge.out.log" -Tail 20   # should show connected/ready, no crash loop
```
(Substitute `$env:WHATSAPP_MCP_SUPPORT_DIR` for `$env:LOCALAPPDATA\whatsapp-mcp` above if you set the override.)

**Reconnecting the bridge** (equivalent of `reconnect-bridge.sh`):
```powershell
powershell -ExecutionPolicy Bypass -File scripts\reconnect-bridge.ps1
```
Same behavior as the macOS script: stops and reinstalls the Scheduled
Tasks. If WhatsApp was logged out, re-pair via QR first (`cd whatsapp-bridge; go run .`),
same as step 2.

## Hands-free morning digest (optional, later phase)

The design includes a scheduler add-on that runs your morning briefing on a
timer and can even send it to your own WhatsApp number, without opening Claude.
It's not part of core setup — see the "Scheduler add-on" section of
[`docs/superpowers/specs/2026-07-04-whatsapp-assistant-v2-design.md`](docs/superpowers/specs/2026-07-04-whatsapp-assistant-v2-design.md).

## Updating

`whatsapp-mcp/` is vendored, so there's no `git pull` inside it. To pick up
upstream changes: clone upstream separately, diff/copy over
`whatsapp-bridge/` and `whatsapp-mcp-server/`, then rebuild and restart the
service from `whatsapp-mcp/`:
```bash
./scripts/install-launchd-macos.sh        # macOS
powershell -File scripts\install-windows.ps1   # Windows
```

## Troubleshooting

**macOS:**

| Symptom | Check |
|---|---|
| Claude Desktop says it can't reach WhatsApp tools | `launchctl list \| grep com.whatsapp-mcp` — is `com.whatsapp-mcp.bridge` running? |
| Bridge keeps restarting in a loop | `tail -50 ~/Library/Logs/whatsapp-mcp/bridge.err.log` |
| Bridge down or needs re-linking | Check for a macOS notification from the monitor job, or `tail ~/Library/Logs/whatsapp-mcp/monitor.err.log` |
| QR code needed again | Usually means the paired session was invalidated on the phone side (device unlinked). Run step 2 again. |
| Chats missing from a Digest | Check they're on the "Allowed chats" list, and not muted/snoozed in the reminders file |
| Assistant forgot my settings | The knowledge files only update when you paste the assistant's new version back in — check you did that after the last change |

**Windows:**

| Symptom | Check |
|---|---|
| Claude Desktop says it can't reach WhatsApp tools | `Get-ScheduledTask -TaskName WhatsAppMCPBridge` — is its `State` `Running` or `Ready`? |
| Bridge keeps restarting in a loop | `Get-Content "$env:LOCALAPPDATA\whatsapp-mcp\logs\bridge.err.log" -Tail 50` |
| Bridge down or needs re-linking | `Get-Content "$env:LOCALAPPDATA\whatsapp-mcp\logs\notifications.log" -Tail 20` (always written; a toast also fires if BurntToast is installed) |
| QR code needed again | Usually means the paired session was invalidated on the phone side (device unlinked). Run step 2 again. |
| Chats missing from a Digest | Check they're on the "Allowed chats" list, and not muted/snoozed in the reminders file |
| Assistant forgot my settings | The knowledge files only update when you paste the assistant's new version back in — check you did that after the last change |
| `go build` fails with a cgo/gcc error | The bridge uses `go-sqlite3` (cgo). Install a C compiler — e.g. via [MSYS2](https://www.msys2.org/) (`pacman -S mingw-w64-x86_64-gcc`) and make sure it's on `PATH` — or skip building and use a pre-built `whatsapp-bridge.exe`. |
| Bridge fails to start with `bind: ... forbidden by its access permissions` | Hyper-V/WSL2/Docker Desktop reserve ranges of ports Windows won't let you bind to (`netsh interface ipv4 show excludedportrange protocol=tcp` lists them). The default port (8090) was chosen to avoid the common ranges; if it still collides on your machine, set `$env:WHATSAPP_BRIDGE_PORT` to something else not in an excluded range before installing, and match it with `WHATSAPP_API_URL` in the Claude Desktop config. |
| Installer fails with `Port ... is already in use after stopping existing whatsapp-mcp tasks` | A leftover `whatsapp-bridge.exe` (or a manually-run `go run .`) from an earlier session is still holding the port. Find and stop it: `Get-NetTCPConnection -LocalPort <port> -State Listen \| Select OwningProcess`, then `Stop-Process -Id <PID> -Force`, then re-run the installer. |
| `Register-ScheduledTask : Access is denied` | You need an elevated ("Run as Administrator") PowerShell window to *register* a Scheduled Task, even though the task itself runs as your regular user account afterward. |
