# Setup

This repo is a companion layer on top of [whatsapp-mcp](https://github.com/verygoodplugins/whatsapp-mcp):
a setup script, a launchd service, and a Claude Desktop Project configuration
that turns the raw WhatsApp MCP tools into a Classify / Digest / Act
assistant. See [`docs/superpowers/specs/2026-07-04-whatsapp-assistant-design.md`](docs/superpowers/specs/2026-07-04-whatsapp-assistant-design.md)
for the design behind this.

Two people may be involved: an **operator** (technical, does most of this)
and an **end user** (only does the steps marked 🙋).

## Prerequisites

- Go 1.24+
- Python 3.11+ and [`uv`](https://docs.astral.sh/uv/)
- Claude Desktop
- (optional, for sending/converting voice notes) `ffmpeg` — `brew install ffmpeg`

## 1. Clone whatsapp-mcp into this repo

```bash
git clone https://github.com/verygoodplugins/whatsapp-mcp.git
```

Run from the root of this repo — it clones into `whatsapp-mcp/`, which this
repo's `.gitignore` intentionally excludes (it's upstream's repo, not ours).

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
cd ../..   # back to this repo's root
./scripts/install-bridge-service.sh
```

This builds a binary and installs a launchd job so the bridge restarts
automatically on login/crash, with no terminal required afterward.

Verify:
```bash
launchctl list | grep com.whatsapp.bridge   # should show a PID, not "-"
tail -20 logs/bridge.log                     # should show connected/ready, no crash loop
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
3. Add [`docs/whatsapp-classification.md`](docs/whatsapp-classification.md) as
   a knowledge file in the Project.

## 7. First conversation (🙋 end user, in the new Project)

Just start talking naturally — e.g. "help me set up my chat categories."
Claude will walk through classifying chats as Work / Personal / Ignore /
High priority and hand back an updated version of the classification file for
you to paste back into the Project's knowledge file. From then on, ask for
things like "what's new today" or "help me reply to Priya" — see
`docs/whatsapp-project-instructions.md` for the full behavior.

## Updating

```bash
cd whatsapp-mcp && git pull
```

If you changed bridge code and are running the built binary (not `go run .`),
rebuild and restart the service:
```bash
./scripts/install-bridge-service.sh
```

## Troubleshooting

| Symptom | Check |
|---|---|
| Claude Desktop says it can't reach WhatsApp tools | `launchctl list \| grep com.whatsapp.bridge` — is it running? |
| Bridge keeps restarting in a loop | `tail -50 logs/bridge.error.log` |
| QR code needed again | Usually means the paired session was invalidated on the phone side (device unlinked). Run step 2 again. |
| Chats missing from a Digest | Check they're not accidentally listed under "Ignore" in the classification file |
