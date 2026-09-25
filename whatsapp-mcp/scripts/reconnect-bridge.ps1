<#
.SYNOPSIS
  Restarts the WhatsApp bridge (Windows Scheduled Task-managed background
  service) when the assistant's data looks stale (e.g. list_chats returns
  messages that are days or weeks old even though new messages should exist).

.DESCRIPTION
  Windows equivalent of reconnect-bridge.sh:
    1. Removes the scheduled tasks (stops the current, possibly stuck bridge).
    2. Reinstalls them (starts a fresh bridge process, auto-starts at logon).

  If the bridge's WhatsApp session has been logged out (common after long
  idle periods, or if you unlinked it from your phone), a restart alone
  won't fix it -- the bridge needs to be re-paired via QR code. In that
  case, after running this script, run the bridge directly in the
  foreground so you can see the QR prompt in the terminal:

      cd whatsapp-bridge
      go run .

  Then scan it with WhatsApp on your phone: Settings -> Linked Devices ->
  Link a Device. Once paired, stop that foreground process (Ctrl+C) and
  re-run this script to go back to the normal scheduled-task background mode.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "== Stopping current bridge (scheduled task) =="
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ScriptDir 'uninstall-windows.ps1')

Write-Host "== Starting bridge fresh (scheduled task) =="
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ScriptDir 'install-windows.ps1')

Write-Host ""
Write-Host "Done. Give it a few seconds to reconnect, then ask your assistant to"
Write-Host "check WhatsApp again (e.g. `"check my whatsapp connection`")."
Write-Host ""
Write-Host "If messages are still stale after this, the session may need re-pairing"
Write-Host "via QR code -- see the comment at the top of this script, or SETUP.md."
