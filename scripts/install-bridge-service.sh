#!/usr/bin/env bash
# Builds the WhatsApp bridge and installs it as a launchd service so it
# survives reboots without anyone opening a terminal again.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRIDGE_DIR="$REPO_ROOT/whatsapp-mcp/whatsapp-bridge"
BRIDGE_BIN="$BRIDGE_DIR/whatsapp-bridge"
LOG_DIR="$REPO_ROOT/logs"
PLIST_LABEL="com.whatsapp.bridge"
PLIST_DEST="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"

if [ ! -d "$BRIDGE_DIR" ]; then
  echo "Error: $BRIDGE_DIR not found. Clone whatsapp-mcp into $REPO_ROOT first." >&2
  exit 1
fi

echo "==> Building bridge binary"
(cd "$BRIDGE_DIR" && go build -o whatsapp-bridge .)

echo "==> Preparing log directory: $LOG_DIR"
mkdir -p "$LOG_DIR"

echo "==> Writing $PLIST_DEST"
sed \
  -e "s#__BRIDGE_BIN__#$BRIDGE_BIN#g" \
  -e "s#__BRIDGE_DIR__#$BRIDGE_DIR#g" \
  -e "s#__LOG_DIR__#$LOG_DIR#g" \
  "$REPO_ROOT/scripts/com.whatsapp.bridge.plist.template" > "$PLIST_DEST"

echo "==> Loading service"
launchctl unload "$PLIST_DEST" 2>/dev/null || true
launchctl load "$PLIST_DEST"

echo "==> Done. Check status with:"
echo "    launchctl list | grep $PLIST_LABEL"
echo "    tail -f $LOG_DIR/bridge.log"
echo ""
echo "NOTE: if this is the first-ever run (no prior WhatsApp pairing), the QR"
echo "code goes to $LOG_DIR/bridge.log, not your terminal. Run"
echo "'cd $BRIDGE_DIR && go run .' by hand once first, scan the QR there,"
echo "then run this script to hand the already-paired bridge off to launchd."
