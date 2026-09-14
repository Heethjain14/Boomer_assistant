# WhatsApp Bridge — Reconnect Runbook

How to tell the bridge is stuck, how to fix it yourself, and how Claude fixes
it for you end-to-end (including showing you a scannable QR code) when you
just say "reconnect my whatsapp."

## How to tell it's stuck

Ask the assistant to check ("check my whatsapp connection" / health check).
It runs `list_chats` — if the most recent message across your chats is many
days or weeks old even though you know newer messages exist, the background
bridge has either (a) stopped running, or (b) is running but its WhatsApp
session got logged out and it's silently waiting for a QR re-scan.

## Path A — do it yourself in Terminal

```bash
cd /Users/apple/Downloads/whatsapp/whatsapp-mcp
./scripts/reconnect-bridge.sh
```

This stops and reinstalls the `launchd` job (`com.whatsapp-mcp.bridge` +
`com.whatsapp-mcp.bridge-monitor`). If the WhatsApp session merely needed a
restart, you're done — give it a few seconds and ask the assistant to check
again.

If the session was logged out, the bridge will sit there waiting for a QR
scan. You'll see it in the logs:

```bash
tail -f /Users/apple/Library/Logs/whatsapp-mcp/bridge.out.log
```

A QR code prints there directly (it regenerates every ~20s until scanned).
Scan it with **WhatsApp on your phone → Settings → Linked Devices → Link a
Device**, then re-run `reconnect-bridge.sh` once more if you want to confirm
it settles into steady state.

## Path B — ask Claude to do it (what happened in this session)

Say "reconnect my whatsapp" / "check and reconnect whatsapp." Here's exactly
what the assistant does, and why, so any future session (or anyone else
running this same project) can reproduce it:

1. **Two different "run something on the Mac" tools exist — use the right one.**
   - `device_bash` (`mcp__remote-devices__device_bash`) looks like a shell on
     your Mac, but it's actually an **isolated Linux sandbox** with your
     connected folder mounted in. It can read/write/grep files fine, but it
     has no `launchctl`, no real `zsh`, and can't drive `launchd` — commands
     that depend on real macOS fail there (e.g. "bad interpreter" or
     "print: command not found" errors when the target script has a
     `#!/bin/zsh` shebang).
   - `mcp__remote-devices__Control_your_Mac__osascript` runs **AppleScript
     `do shell script "..."` directly on the real Mac**, as the actual logged
     in user. This is what can actually call `launchctl` / `zsh` and pair a
     real WhatsApp session. Verify it's really the Mac with a sanity check
     first (`do shell script "whoami"`).
2. **Restart the bridge for real**, via osascript, explicitly through zsh
   (the install/uninstall scripts use zsh builtins like `print`, so invoke
   them as `/bin/zsh ./scripts/uninstall-launchd-macos.sh` and
   `/bin/zsh ./scripts/install-launchd-macos.sh` rather than plain `bash`):
   ```
   do shell script "cd /Users/apple/Downloads/whatsapp/whatsapp-mcp && /bin/zsh ./scripts/uninstall-launchd-macos.sh 2>&1"
   do shell script "cd /Users/apple/Downloads/whatsapp/whatsapp-mcp && /bin/zsh ./scripts/install-launchd-macos.sh 2>&1"
   ```
3. **Check the logs for a QR prompt:**
   ```
   do shell script "sleep 5 && tail -n 60 /Users/apple/Library/Logs/whatsapp-mcp/bridge.out.log"
   ```
   If `Waiting for QR code scan...` shows up, the session needs re-pairing.
4. **Pull out just the freshest QR payload** (it's a `wa.me/settings/linked_devices#...`
   URL embedded in the log noise), right before generating the image since it
   expires in ~20 seconds:
   ```
   do shell script "grep -o 'https://wa.me/settings/linked_devices#[^\\[]*' /Users/apple/Library/Logs/whatsapp-mcp/bridge.out.log | tail -n 1"
   ```
5. **Render it as an actual scannable QR image** in the cloud workspace
   (the ASCII-art QR in the log doesn't render usably in chat):
   ```python
   import qrcode
   img = qrcode.make(data)
   img.save("/mnt/user-data/outputs/whatsapp-qr.png")
   ```
   (`pip install qrcode[pil] --break-system-packages` first if missing.)
6. **Send it with `SendUserFile`** and tell the user to scan it *now* —
   codes rotate every ~20s, so fetch step 4 fresh right before generating
   and sending; if it's missed, just repeat steps 4–6 ("refresh the QR").
7. **Verify** by re-running `list_chats` and confirming the newest message
   timestamp is current (not days/weeks old).

## Files

- `scripts/reconnect-bridge.sh` — the one-command restart (Path A). Safe to
  run anytime the bridge looks stuck; it preserves bridge data
  (`whatsapp-bridge/store/`), only touches the launchd registration.
- This doc — the full runbook, including the Claude-driven QR flow (Path B).

## Notes / gotchas learned the hard way

- Don't assume `device_bash` can drive macOS-native services — it's a
  sandbox, not your real shell, even though it shares the mounted folder.
- The uninstall/install scripts are zsh scripts; running them with plain
  `bash` fails on zsh-only builtins. Always invoke them with `/bin/zsh`
  explicitly (or their own shebang, when actually run on macOS with `zsh`
  available as `/bin/zsh`, which it always is).
- A QR-scan requirement is normal after long idle periods or if the phone
  unlinked the device — it isn't a sign anything is broken beyond needing a
  fresh pair.
