<#
.SYNOPSIS
  Fixture-based tests for install-windows.ps1 / uninstall-windows.ps1,
  mirroring scripts/tests/test-launchd-macos.sh for the macOS installer.

  Run with: pwsh -File scripts/tests/test-windows-task.ps1
#>

$ErrorActionPreference = 'Stop'
$global:failures = 0
$global:registeredTasks = @{}
$global:cmdLog = New-Object System.Collections.Generic.List[string]

function Test-Fail([string]$Message) {
    Write-Host "FAIL: $Message" -ForegroundColor Red
    $global:failures++
}

function Assert-FileExists([string]$Path) {
    if (-not (Test-Path -PathType Leaf $Path)) { Test-Fail "expected file: $Path" }
}

function Assert-NotExists([string]$Path) {
    if (Test-Path $Path) { Test-Fail "expected path to be removed: $Path" }
}

function Assert-Contains([string]$Path, [string]$Needle) {
    if (-not (Test-Path $Path)) { Test-Fail "expected $Path to exist to check content"; return }
    $content = Get-Content -Path $Path -Raw
    if ($content -notlike "*$Needle*") { Test-Fail "expected $Path to contain: $Needle" }
}

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { Test-Fail $Message }
}

# --- fake Scheduled Tasks module surface ----------------------------------
function Get-ScheduledTask {
    param([string]$TaskName, [string]$ErrorAction)
    $global:cmdLog.Add("Get-ScheduledTask -TaskName $TaskName")
    if ($global:registeredTasks.ContainsKey($TaskName)) {
        return [pscustomobject]@{ TaskName = $TaskName; State = 'Ready' }
    }
    return $null
}

function Stop-ScheduledTask {
    param([string]$TaskName, [string]$ErrorAction)
    $global:cmdLog.Add("Stop-ScheduledTask -TaskName $TaskName")
}

function Unregister-ScheduledTask {
    param([string]$TaskName, [switch]$Confirm, [string]$ErrorAction)
    $global:cmdLog.Add("Unregister-ScheduledTask -TaskName $TaskName")
    $global:registeredTasks.Remove($TaskName) | Out-Null
}

function New-ScheduledTaskAction {
    param([string]$Execute, [string]$Argument)
    return [pscustomobject]@{ Execute = $Execute; Argument = $Argument }
}

function New-ScheduledTaskTrigger {
    param([switch]$AtLogOn, [switch]$Once, [datetime]$At, [timespan]$RepetitionInterval, [timespan]$RepetitionDuration)
    return [pscustomobject]@{ AtLogOn = $AtLogOn.IsPresent; Once = $Once.IsPresent }
}

function New-ScheduledTaskSettingsSet {
    param(
        [int]$RestartCount, [timespan]$RestartInterval, [timespan]$ExecutionTimeLimit,
        [switch]$AllowStartIfOnBatteries, [switch]$DontStopIfGoingOnBatteries, [switch]$StartWhenAvailable
    )
    return [pscustomobject]@{ RestartCount = $RestartCount }
}

function New-ScheduledTaskPrincipal {
    param([string]$UserId, [string]$LogonType, [string]$RunLevel)
    return [pscustomobject]@{ UserId = $UserId }
}

function Register-ScheduledTask {
    param([string]$TaskName, $Action, $Trigger, $Settings, $Principal, [switch]$Force)
    $global:cmdLog.Add("Register-ScheduledTask -TaskName $TaskName -Execute $($Action.Argument)")
    $global:registeredTasks[$TaskName] = $Action
}

function Start-ScheduledTask {
    param([string]$TaskName)
    $global:cmdLog.Add("Start-ScheduledTask -TaskName $TaskName")
}

function Get-NetTCPConnection {
    param([int]$LocalPort, [string]$State, [string]$ErrorAction)
    return $null
}

function New-Fixture {
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("whatsapp-mcp-win-test-" + [guid]::NewGuid().ToString("N"))
    $repo = Join-Path $tmp 'repo'
    $localAppData = Join-Path $tmp 'localappdata'
    $fakeBin = Join-Path $tmp 'fakebin'
    New-Item -ItemType Directory -Force -Path (Join-Path $repo 'scripts'), (Join-Path $repo 'whatsapp-bridge\store'), $localAppData, $fakeBin | Out-Null

    $realScriptDir = Split-Path -Parent $PSScriptRoot
    Copy-Item (Join-Path $realScriptDir 'install-windows.ps1') (Join-Path $repo 'scripts')
    Copy-Item (Join-Path $realScriptDir 'uninstall-windows.ps1') (Join-Path $repo 'scripts')

    # Fake `go` on PATH: writes a stub exe file instead of actually building.
    $fakeGo = Join-Path $fakeBin 'go'
    $fakeGoScript = @'
#!/bin/sh
out=""
prev=""
for a in "$@"; do
  if [ "$prev" = "-o" ]; then
    out="$a"
  fi
  prev="$a"
done
if [ -n "$out" ]; then
  printf '#!/bin/sh\nexit 0\n' > "$out"
  chmod +x "$out"
fi
exit 0
'@
    Set-Content -Path $fakeGo -Value $fakeGoScript
    if ($env:OS -ne 'Windows_NT') {
        & chmod +x $fakeGo
    }

    return [pscustomobject]@{ Root = $tmp; Repo = $repo; LocalAppData = $localAppData; FakeBin = $fakeBin }
}

function Invoke-Install([pscustomobject]$Fixture) {
    $oldLocalAppData = $env:LOCALAPPDATA
    $oldPath = $env:PATH
    $oldOs = $env:OS
    try {
        $env:LOCALAPPDATA = $Fixture.LocalAppData
        $env:PATH = "$($Fixture.FakeBin)$([IO.Path]::PathSeparator)$oldPath"
        $env:OS = 'Windows_NT'
        & (Join-Path $Fixture.Repo 'scripts\install-windows.ps1')
    } finally {
        $env:LOCALAPPDATA = $oldLocalAppData
        $env:PATH = $oldPath
        $env:OS = $oldOs
    }
}

function Invoke-Uninstall([pscustomobject]$Fixture) {
    $oldLocalAppData = $env:LOCALAPPDATA
    $oldOs = $env:OS
    try {
        $env:LOCALAPPDATA = $Fixture.LocalAppData
        $env:OS = 'Windows_NT'
        & (Join-Path $Fixture.Repo 'scripts\uninstall-windows.ps1')
    } finally {
        $env:LOCALAPPDATA = $oldLocalAppData
        $env:OS = $oldOs
    }
}

function Test-InstallGeneratesTaskFiles {
    $global:registeredTasks = @{}
    $global:cmdLog.Clear()
    $fixture = New-Fixture
    Invoke-Install $fixture

    $support = Join-Path $fixture.LocalAppData 'whatsapp-mcp'
    Assert-FileExists (Join-Path $support 'task.env.ps1')
    Assert-FileExists (Join-Path $support 'run-whatsapp-bridge.ps1')
    Assert-FileExists (Join-Path $support 'monitor-whatsapp-bridge.ps1')
    Assert-Contains (Join-Path $support 'task.env.ps1') "WHATSAPP_BRIDGE_PORT = '8090'"
    Assert-Contains (Join-Path $support 'task.env.ps1') "WHATSAPP_API_URL = 'http://127.0.0.1:8090/api'"
    Assert-True $global:registeredTasks.ContainsKey('WhatsAppMCPBridge') "expected WhatsAppMCPBridge task registered"
    Assert-True $global:registeredTasks.ContainsKey('WhatsAppMCPBridgeMonitor') "expected WhatsAppMCPBridgeMonitor task registered"
    Assert-True (($global:cmdLog -join "`n") -match 'Start-ScheduledTask -TaskName WhatsAppMCPBridge') "expected bridge task to be started"

    Remove-Item -Recurse -Force $fixture.Root -ErrorAction SilentlyContinue
}

function Test-InstallPreservesOptionalEnvValues {
    $global:registeredTasks = @{}
    $global:cmdLog.Clear()
    $fixture = New-Fixture
    $oldPort = $env:WHATSAPP_BRIDGE_PORT
    $oldWebhook = $env:WEBHOOK_URL
    try {
        $env:WHATSAPP_BRIDGE_PORT = '9090'
        $env:WEBHOOK_URL = 'http://127.0.0.1:8769/whatsapp/webhook'
        Invoke-Install $fixture
    } finally {
        $env:WHATSAPP_BRIDGE_PORT = $oldPort
        $env:WEBHOOK_URL = $oldWebhook
    }

    $support = Join-Path $fixture.LocalAppData 'whatsapp-mcp'
    Assert-Contains (Join-Path $support 'task.env.ps1') "WHATSAPP_BRIDGE_PORT = '9090'"
    Assert-Contains (Join-Path $support 'task.env.ps1') "WHATSAPP_API_URL = 'http://127.0.0.1:9090/api'"
    Assert-Contains (Join-Path $support 'task.env.ps1') "WEBHOOK_URL = 'http://127.0.0.1:8769/whatsapp/webhook'"

    Remove-Item -Recurse -Force $fixture.Root -ErrorAction SilentlyContinue
}

function Test-InstallRespectsSupportDirOverride {
    $global:registeredTasks = @{}
    $global:cmdLog.Clear()
    $fixture = New-Fixture
    $overrideDir = Join-Path $fixture.Root 'custom-support-dir'
    $oldSupportDir = $env:WHATSAPP_MCP_SUPPORT_DIR
    try {
        $env:WHATSAPP_MCP_SUPPORT_DIR = $overrideDir
        Invoke-Install $fixture
    } finally {
        $env:WHATSAPP_MCP_SUPPORT_DIR = $oldSupportDir
    }

    Assert-FileExists (Join-Path $overrideDir 'task.env.ps1')
    Assert-FileExists (Join-Path $overrideDir 'run-whatsapp-bridge.ps1')
    Assert-NotExists (Join-Path $fixture.LocalAppData 'whatsapp-mcp')

    Remove-Item -Recurse -Force $fixture.Root -ErrorAction SilentlyContinue
}

function Test-UninstallRemovesGeneratedFilesOnly {
    $global:registeredTasks = @{}
    $global:cmdLog.Clear()
    $fixture = New-Fixture
    Invoke-Install $fixture

    $support = Join-Path $fixture.LocalAppData 'whatsapp-mcp'
    Set-Content -Path (Join-Path $fixture.Repo 'whatsapp-bridge\store\messages.db') -Value 'db'

    Invoke-Uninstall $fixture

    Assert-NotExists (Join-Path $support 'task.env.ps1')
    Assert-NotExists (Join-Path $support 'run-whatsapp-bridge.ps1')
    Assert-NotExists (Join-Path $support 'monitor-whatsapp-bridge.ps1')
    Assert-NotExists (Join-Path $support 'state')
    Assert-FileExists (Join-Path $fixture.Repo 'whatsapp-bridge\store\messages.db')
    Assert-True (-not $global:registeredTasks.ContainsKey('WhatsAppMCPBridge')) "expected bridge task removed"
    Assert-True (-not $global:registeredTasks.ContainsKey('WhatsAppMCPBridgeMonitor')) "expected monitor task removed"

    Remove-Item -Recurse -Force $fixture.Root -ErrorAction SilentlyContinue
}

Write-Host "Running Test-InstallGeneratesTaskFiles"
Test-InstallGeneratesTaskFiles
Write-Host "Running Test-InstallPreservesOptionalEnvValues"
Test-InstallPreservesOptionalEnvValues
Write-Host "Running Test-InstallRespectsSupportDirOverride"
Test-InstallRespectsSupportDirOverride
Write-Host "Running Test-UninstallRemovesGeneratedFilesOnly"
Test-UninstallRemovesGeneratedFilesOnly

if ($global:failures -gt 0) {
    Write-Host "$($global:failures) test failure(s)" -ForegroundColor Red
    exit 1
}
Write-Host "All Windows scheduled-task script tests passed" -ForegroundColor Green
