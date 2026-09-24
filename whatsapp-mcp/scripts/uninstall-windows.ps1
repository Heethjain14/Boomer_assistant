<#
.SYNOPSIS
  Removes the whatsapp-mcp Windows scheduled tasks installed by
  install-windows.ps1 (Windows equivalent of uninstall-launchd-macos.sh).

  Preserves bridge data under whatsapp-bridge\store\ and leaves log files
  in place; only removes the generated support files and scheduled tasks.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    Write-Error "Error: $Message"
    exit 1
}

if ($env:OS -ne 'Windows_NT') {
    Fail "This uninstaller only supports Windows. Use uninstall-launchd-macos.sh on macOS."
}

$BridgeTaskName = 'WhatsAppMCPBridge'
$MonitorTaskName = 'WhatsAppMCPBridgeMonitor'

if (-not $env:LOCALAPPDATA) {
    Fail "LOCALAPPDATA is not set; cannot determine where support files live."
}

$SupportDir = Join-Path $env:LOCALAPPDATA 'whatsapp-mcp'
$StateDir = Join-Path $SupportDir 'state'

Write-Host "Stopping whatsapp-mcp scheduled tasks if present..."
foreach ($name in @($MonitorTaskName, $BridgeTaskName)) {
    $existing = Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
    if ($existing) {
        Stop-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $name -Confirm:$false -ErrorAction SilentlyContinue
    }
}

Remove-Item -Path (Join-Path $SupportDir 'run-whatsapp-bridge.ps1') -Force -ErrorAction SilentlyContinue
Remove-Item -Path (Join-Path $SupportDir 'monitor-whatsapp-bridge.ps1') -Force -ErrorAction SilentlyContinue
Remove-Item -Path (Join-Path $SupportDir 'task.env.ps1') -Force -ErrorAction SilentlyContinue
Remove-Item -Path $StateDir -Recurse -Force -ErrorAction SilentlyContinue

if ((Test-Path $SupportDir) -and -not (Get-ChildItem -Path $SupportDir -Force -ErrorAction SilentlyContinue)) {
    Remove-Item -Path $SupportDir -Force -ErrorAction SilentlyContinue
}

Write-Host "Removed whatsapp-mcp scheduled tasks and generated support files."
Write-Host "Preserved bridge data under whatsapp-bridge\store\."
Write-Host "Logs (if any) were left in place under: $(Join-Path $SupportDir 'logs')"
