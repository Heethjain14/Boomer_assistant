#!/usr/bin/env bash
#
# reconnect-bridge.sh
#
# Restarts the WhatsApp bridge (launchd-managed background service) when the
# assistant's data looks stale (e.g. list_chats returns messages that are days
# or weeks old even though new messages should exist).
#
# Usage:
#   ./scripts/reconnect-bridge.sh
#
# What it does:
#   1. Uninstalls the launchd job (stops the current, possibly stuck bridge).
#   2. Reinstalls it (starts a fresh bridge process, auto-starts on login).
#
# If the bridge's WhatsApp session has been logged out (common after long
# idle periods, or if you unlinked it from your phone), a restart alone won't
# fix it — the bridge needs to be re-paired via QR code. In that case, after
# running this script, run the bridge directly in the foreground so you can
# see the QR prompt in the terminal:
#
#   cd whatsapp-bridge && go run main.go
#   (or the equivalent binary/command documented in SETUP.md)
#
# Then scan it with WhatsApp on your phone: Settings -> Linked Devices ->
# Link a Device. Once paired, stop that foreground process (Ctrl+C) and
# re-run this script to go back to the normal launchd-managed background mode.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "== Stopping current bridge (launchd) =="
/bin/zsh "$SCRIPT_DIR/uninstall-launchd-macos.sh"

echo "== Starting bridge fresh (launchd) =="
/bin/zsh "$SCRIPT_DIR/install-launchd-macos.sh"

echo
echo "Done. Give it a few seconds to reconnect, then ask your assistant to"
echo "check WhatsApp again (e.g. \"check my whatsapp connection\")."
echo
echo "If messages are still stale after this, the session may need re-pairing"
echo "via QR code -- see the comment at the top of this script, or SETUP.md."
