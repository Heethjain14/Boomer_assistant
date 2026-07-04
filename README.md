# WhatsApp Assistant

A personal WhatsApp assistant that runs on your Mac through Claude Desktop. It
reads only the chats you allow, gives you a structured morning briefing, tracks
reminders and follow-ups, drafts replies (never sends without your say-so), and
can be reconfigured entirely by talking to it.

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

## How it's built

| Piece | What it is |
|---|---|
| `whatsapp-mcp/` | vendored bridge (Go) + MCP server (Python) — talks to WhatsApp |
| `whatsapp-mcp/scripts/install-launchd-macos.sh` | makes the bridge auto-start persistently |
| `docs/whatsapp-project-instructions.md` | the assistant's behavior (paste into a Claude Desktop Project) |
| `docs/whatsapp-profile.md` | who you are + preferences (Project knowledge file) |
| `docs/whatsapp-classification.md` | allowed chats + categories + last-digested (knowledge file) |
| `docs/whatsapp-reminders.md` | reminders, follow-ups, dates (knowledge file) |

Design details: [`docs/superpowers/specs/2026-07-04-whatsapp-assistant-v2-design.md`](docs/superpowers/specs/2026-07-04-whatsapp-assistant-v2-design.md).

## Setup

See [SETUP.md](SETUP.md) — clone, pair WhatsApp once (QR code), install the
background service, point Claude Desktop at it, and create the Project.

## Security

This uses WhatsApp tools with an AI, so mind the basics: it only reads chats you
explicitly allow, treats message content as untrusted (won't act on instructions
hidden inside messages), and never sends a message to anyone without your
explicit confirmation of that exact draft. Your messages stay in a local SQLite
database on your Mac; they're only sent to Claude when you ask for something.
