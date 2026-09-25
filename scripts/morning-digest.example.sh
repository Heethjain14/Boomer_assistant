#!/usr/bin/env bash
#
# Scheduler add-on (LATER PHASE — not wired up by default).
#
# Runs your morning WhatsApp digest hands-free by invoking Claude Code
# headlessly against the same local MCP server the Desktop Project uses, then
# (optionally) sending the result to your OWN WhatsApp number so the brief lands
# on your phone. Sending to yourself is the one send that doesn't need per-draft
# confirmation; it never messages a contact.
#
# PREREQUISITES (do these before relying on this):
#   1. Claude Code CLI installed and logged in (`claude` on your PATH).
#   2. The WhatsApp MCP server registered with Claude Code, e.g.:
#        claude mcp add whatsapp -- uv --directory \
#          /Users/apple/Downloads/whatsapp/whatsapp-mcp/whatsapp-mcp-server run main.py
#   3. The bridge running (it is, via install-launchd-macos.sh).
#
# Then schedule this with a launchd job (a .plist with StartCalendarInterval),
# NOT cron, to match how the bridge is managed. See the design spec.
#
# This is a STARTING POINT. Test it by hand first:  ./morning-digest.example.sh
set -euo pipefail

# The prompt the headless run executes. Keep it aligned with the Digest mode in
# docs/whatsapp-project-instructions.md.
read -r -d '' PROMPT <<'EOF' || true
You are my WhatsApp assistant. Produce my morning digest over my allowed chats
since each chat's last check (default last 24h): priority messages first, then
reminders due today, then an action-item list, as a compact table. Do not send
anything to any contact.
EOF

# Generate the digest headlessly.
DIGEST="$(claude -p "$PROMPT" 2>/dev/null)"

# Delivery option A: just print it (launchd will capture to a log file).
printf '%s\n' "$DIGEST"

# Delivery option B (uncomment + set your own number): send it to yourself on
# WhatsApp. Requires the bridge token; sends to YOUR number only.
#
# MY_NUMBER="9199XXXXXXXX"   # your own WhatsApp number, country code, no +
# TOKEN="$(cat /Users/apple/Downloads/whatsapp/whatsapp-mcp/whatsapp-bridge/store/.bridge-token)"
# curl -s -X POST http://localhost:8090/api/send \
#   -H "Authorization: Bearer $TOKEN" \
#   -H "Content-Type: application/json" \
#   -d "$(python3 -c 'import json,sys; print(json.dumps({"recipient": sys.argv[1]+"@s.whatsapp.net", "message": sys.argv[2]}))' "$MY_NUMBER" "$DIGEST")"
