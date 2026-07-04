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

## Prerequisites

- Go 1.24+
- Python 3.11+ and [`uv`](https://docs.astral.sh/uv/)
- Claude Desktop
- (optional, for sending/converting voice notes) `ffmpeg` — `brew install ffmpeg`

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

## 4. Configure Claude Desktop (operator, or 🙋 if comfortable pasting JSON)

Edit `~/Library/Application Support/Claude/claude_desktop_config.json`:

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

Replace the path with the real absolute path on this machine. Fully quit
Claude Desktop (Cmd+Q) and reopen it.

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

After step 3, the bridge runs as a launchd service:
- **Close the lid / sleep:** keeps running, resumes on wake.
- **Shut down / restart:** auto-starts again when you log in.
- **Crash:** restarts itself.

To **disable** auto-start: `cd whatsapp-mcp && ./scripts/uninstall-launchd-macos.sh`.
To **re-enable**: `./scripts/install-launchd-macos.sh`. You can also just ask
the assistant ("turn off morning auto-start") and it'll give you the command.

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
./scripts/install-launchd-macos.sh
```

## Troubleshooting

| Symptom | Check |
|---|---|
| Claude Desktop says it can't reach WhatsApp tools | `launchctl list \| grep com.whatsapp-mcp` — is `com.whatsapp-mcp.bridge` running? |
| Bridge keeps restarting in a loop | `tail -50 ~/Library/Logs/whatsapp-mcp/bridge.err.log` |
| Bridge down or needs re-linking | Check for a macOS notification from the monitor job, or `tail ~/Library/Logs/whatsapp-mcp/monitor.err.log` |
| QR code needed again | Usually means the paired session was invalidated on the phone side (device unlinked). Run step 2 again. |
| Chats missing from a Digest | Check they're on the "Allowed chats" list, and not muted/snoozed in the reminders file |
| Assistant forgot my settings | The knowledge files only update when you paste the assistant's new version back in — check you did that after the last change |
