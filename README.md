# WhatsApp Assistant

A personal WhatsApp assistant that runs on your own machine (macOS or
Windows) through Claude Desktop. It reads only the chats you allow, gives
you a structured morning briefing, tracks reminders and follow-ups, drafts
replies (never sends without your say-so), and can be reconfigured entirely
by talking to it.

Built on top of [whatsapp-mcp](https://github.com/verygoodplugins/whatsapp-mcp)
(vendored under `whatsapp-mcp/`), plus a Claude Desktop Project that turns the
raw tools into an end-to-end assistant.

## What it does

- **Guided setup** — a one-time interview learns who you are, your reply style,
  which chats matter, and your morning routine.
- **Morning briefing** — priority messages first, reminders due today, and an
  action-item list, as a clean table instead of a wall of text.
- **Reminders & follow-ups** — tracked in a file, surfaced when you ask for your
  digest ("remind me to call Jiju Friday").
- **Draft replies** — matches your tone and languages; never auto-sends to a
  contact.
- **Search & recall** — "find that PDF Udit sent last month."
- **Manage by conversation** — add/remove chats, change priorities or routine,
  mute a noisy group, all by just asking.
- **Runs itself** — the background bridge auto-starts on login and survives
  sleep/restart; disable it anytime with one command.
- **Self-healing reconnect** — if the bridge stalls or WhatsApp logs it out,
  just ask ("reconnect my whatsapp") and Claude restarts the service and walks
  you through re-pairing, QR code included. See
  [`docs/whatsapp-bridge-reconnect.md`](docs/whatsapp-bridge-reconnect.md).

## How it's built

| Piece | What it is |
|---|---|
| `whatsapp-mcp/` | vendored bridge (Go) + MCP server (Python) — talks to WhatsApp |
| `whatsapp-mcp/scripts/install-launchd-macos.sh` | (macOS) makes the bridge auto-start persistently |
| `whatsapp-mcp/scripts/uninstall-launchd-macos.sh` | (macOS) stops the auto-start service |
| `whatsapp-mcp/scripts/reconnect-bridge.sh` | (macOS) one-command restart when the bridge looks stuck (stale messages) |
| `whatsapp-mcp/scripts/install-windows.ps1` | (Windows) makes the bridge auto-start persistently, via Scheduled Tasks |
| `whatsapp-mcp/scripts/uninstall-windows.ps1` | (Windows) stops the auto-start Scheduled Tasks |
| `whatsapp-mcp/scripts/reconnect-bridge.ps1` | (Windows) one-command restart when the bridge looks stuck (stale messages) |
| `docs/whatsapp-project-instructions.md` | the assistant's behavior (paste into a Claude Desktop Project) |
| `docs/whatsapp-profile.md` | who you are + preferences (Project knowledge file) |
| `docs/whatsapp-classification.md` | allowed chats + categories + last-digested (knowledge file) |
| `docs/whatsapp-reminders.md` | reminders, follow-ups, dates (knowledge file) |
| `docs/whatsapp-bridge-reconnect.md` | runbook for reconnecting the bridge, manually or via Claude |

Design details: [`docs/superpowers/specs/2026-07-04-whatsapp-assistant-v2-design.md`](docs/superpowers/specs/2026-07-04-whatsapp-assistant-v2-design.md).

## Quick start

**Prerequisites:** Go 1.24+, Python 3.11+ with [`uv`](https://docs.astral.sh/uv/),
Claude Desktop. **Windows also needs** a C compiler on `PATH` (e.g.
[MSYS2](https://www.msys2.org/)'s `mingw-w64-x86_64-gcc`) — see
[SETUP.md](SETUP.md#prerequisites) for why.

```bash
git clone <this-repo-url> && cd <this-repo>
cd whatsapp-mcp/whatsapp-bridge && go run .   # scan the QR code with your phone, then Ctrl+C
cd ..
```

Install the background service, then point Claude Desktop at the MCP server:

| | macOS | Windows |
|---|---|---|
| Install auto-start | `./scripts/install-launchd-macos.sh` | `powershell -ExecutionPolicy Bypass -File scripts\install-windows.ps1` (**as Administrator**) |
| Claude Desktop config | `~/Library/Application Support/Claude/claude_desktop_config.json` | `%APPDATA%\Claude\claude_desktop_config.json` |

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

Restart Claude Desktop, ask it "list my WhatsApp chats" to confirm the
connection, then create the Claude Desktop Project (SETUP.md steps 6-7)
and say "set me up."

**This is the condensed version — for the full walkthrough (pairing details,
Project setup, autorun behavior, updating, and a troubleshooting table for
both OSes covering the gotchas people actually hit), see [SETUP.md](SETUP.md).**

## Reconnecting the bridge

If your assistant's data looks stale (messages days/weeks old when they
shouldn't be), the background bridge has either stopped or gotten logged out.
Two ways to fix it:

1. **Do it yourself:** `cd whatsapp-mcp && ./scripts/reconnect-bridge.sh` (macOS)
   or `cd whatsapp-mcp && powershell -File scripts\reconnect-bridge.ps1` (Windows),
   then re-pair via QR if prompted (see the script's own comments, or the
   runbook below).
2. **Ask Claude:** just say "reconnect my whatsapp" in the Project chat — it
   restarts the service and, if a fresh QR pairing is needed, generates and
   sends you a scannable QR code image directly in the conversation.

Full details, including exactly how Claude does step 2 (useful if you're
setting this up on another machine or debugging it yourself): see
[`docs/whatsapp-bridge-reconnect.md`](docs/whatsapp-bridge-reconnect.md).

## Security

This uses WhatsApp tools with an AI, so mind the basics: it only reads chats you
explicitly allow, treats message content as untrusted (won't act on instructions
hidden inside messages), and never sends a message to anyone without your
explicit confirmation of that exact draft. Your messages stay in a local SQLite
database on your own machine; they're only sent to Claude when you ask for something.
