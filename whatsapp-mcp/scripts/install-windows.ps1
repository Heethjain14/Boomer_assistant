<#
.SYNOPSIS
  Installs the WhatsApp MCP bridge as an auto-starting Windows background
  task (Windows equivalent of install-launchd-macos.sh).

.DESCRIPTION
  Builds the bridge binary (if Go is available), writes a small env file and
  two generated runner scripts (bridge + health monitor), and registers two
  Scheduled Tasks:
    - WhatsAppMCPBridge         runs the bridge at logon, restarts on crash
    - WhatsAppMCPBridgeMonitor  runs every 60s, alerts (toast + log) if the
                                bridge is down, unreachable, or needs re-linking

  Safe to re-run: it stops/removes any existing whatsapp-mcp tasks first.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    Write-Error "Error: $Message"
    exit 1
}

function Require-Windows {
    if ($env:OS -ne 'Windows_NT') {
        Fail "This installer only supports Windows. Use install-launchd-macos.sh on macOS."
    }
}

Require-Windows

$BridgeTaskName = 'WhatsAppMCPBridge'
$MonitorTaskName = 'WhatsAppMCPBridgeMonitor'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$BridgeDir = Join-Path $RepoRoot 'whatsapp-bridge'
$BridgeBinary = Join-Path $BridgeDir 'whatsapp-bridge.exe'

if (-not (Test-Path $BridgeDir)) {
    Fail "Could not find bridge directory: $BridgeDir"
}

$Port = if ($env:WHATSAPP_BRIDGE_PORT) { $env:WHATSAPP_BRIDGE_PORT } else { '8090' }
if ($Port -notmatch '^[0-9]+$' -or [int]$Port -lt 1 -or [int]$Port -gt 65535) {
    Fail "WHATSAPP_BRIDGE_PORT must be a number between 1 and 65535, got: $Port"
}
$ApiUrl = if ($env:WHATSAPP_API_URL) { $env:WHATSAPP_API_URL } else { "http://127.0.0.1:$Port/api" }

if (-not $env:WHATSAPP_MCP_SUPPORT_DIR -and -not $env:LOCALAPPDATA) {
    Fail "LOCALAPPDATA is not set; cannot determine where to install support files. Set WHATSAPP_MCP_SUPPORT_DIR to an explicit path instead."
}

# Config/state/log files live here. Small (KBs) -- defaults to %LOCALAPPDATA%,
# but WHATSAPP_MCP_SUPPORT_DIR lets you redirect them (e.g. to a drive other
# than C: if it's low on space).
$SupportDir = if ($env:WHATSAPP_MCP_SUPPORT_DIR) { $env:WHATSAPP_MCP_SUPPORT_DIR } else { Join-Path $env:LOCALAPPDATA 'whatsapp-mcp' }
$StateDir = Join-Path $SupportDir 'state'
$LogDir = Join-Path $SupportDir 'logs'
$EnvFile = Join-Path $SupportDir 'task.env.ps1'
$RunnerScript = Join-Path $SupportDir 'run-whatsapp-bridge.ps1'
$MonitorScript = Join-Path $SupportDir 'monitor-whatsapp-bridge.ps1'

New-Item -ItemType Directory -Force -Path $SupportDir, $StateDir, $LogDir | Out-Null

$goCmd = Get-Command go -ErrorAction SilentlyContinue
if ($goCmd) {
    Write-Host "Building WhatsApp bridge..."
    Push-Location $BridgeDir
    try {
        & go build -o $BridgeBinary .
        if ($LASTEXITCODE -ne 0) { Fail "go build failed with exit code $LASTEXITCODE" }
    } finally {
        Pop-Location
    }
} elseif (-not (Test-Path $BridgeBinary)) {
    Fail "Go is not available and no executable bridge binary exists at $BridgeBinary."
}

if (-not (Test-Path $BridgeBinary)) {
    Fail "Bridge binary is missing: $BridgeBinary"
}

Write-Host "Stopping existing whatsapp-mcp scheduled tasks if present..."
foreach ($name in @($MonitorTaskName, $BridgeTaskName)) {
    $existing = Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
    if ($existing) {
        Stop-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $name -Confirm:$false -ErrorAction SilentlyContinue
    }
}

$portInUse = $false
try {
    $conns = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    if ($conns) { $portInUse = $true }
} catch {
    # Get-NetTCPConnection may be unavailable (older Windows); skip the check.
}
if ($portInUse) {
    Fail "Port $Port is already in use after stopping existing whatsapp-mcp tasks."
}

# --- env file -----------------------------------------------------------
$envLines = New-Object System.Collections.Generic.List[string]
function Add-EnvLine([string]$Name, [string]$Value) {
    $escaped = $Value -replace "'", "''"
    $envLines.Add("`$env:$Name = '$escaped'")
}

Add-EnvLine 'WHATSAPP_MCP_REPO_ROOT' $RepoRoot
Add-EnvLine 'WHATSAPP_BRIDGE_DIR' $BridgeDir
Add-EnvLine 'WHATSAPP_BRIDGE_BINARY' $BridgeBinary
Add-EnvLine 'WHATSAPP_BRIDGE_PORT' $Port
Add-EnvLine 'WHATSAPP_API_URL' $ApiUrl
Add-EnvLine 'WHATSAPP_MCP_LOG_DIR' $LogDir
Add-EnvLine 'WHATSAPP_MCP_STATE_DIR' $StateDir

foreach ($optionalVar in @('WEBHOOK_URL', 'FORWARD_SELF', 'WHATSAPP_BRIDGE_TOKEN', 'WHATSAPP_MEDIA_ROOTS')) {
    $val = [System.Environment]::GetEnvironmentVariable($optionalVar)
    if (-not [string]::IsNullOrEmpty($val)) {
        Add-EnvLine $optionalVar $val
    }
}

Set-Content -Path $EnvFile -Value $envLines -Encoding UTF8

# --- runner script (the bridge process itself) ---------------------------
$runnerTemplate = @'
$ErrorActionPreference = 'Stop'
. "__ENV_FILE__"
Set-Location $env:WHATSAPP_BRIDGE_DIR
$outLog = Join-Path $env:WHATSAPP_MCP_LOG_DIR 'bridge.out.log'
$errLog = Join-Path $env:WHATSAPP_MCP_LOG_DIR 'bridge.err.log'
& $env:WHATSAPP_BRIDGE_BINARY 1>> $outLog 2>> $errLog
'@
$runnerContent = $runnerTemplate.Replace('__ENV_FILE__', $EnvFile)
Set-Content -Path $RunnerScript -Value $runnerContent -Encoding UTF8

# --- monitor script (health check, runs every 60s) ------------------------
$monitorTemplate = @'
$ErrorActionPreference = 'Continue'
. "__ENV_FILE__"

$BridgeTaskName = "__BRIDGE_TASK_NAME__"
$StateDir = $env:WHATSAPP_MCP_STATE_DIR
$LogDir = $env:WHATSAPP_MCP_LOG_DIR
$TokenFile = Join-Path $env:WHATSAPP_BRIDGE_DIR 'store\.bridge-token'
$BridgeLog = Join-Path $LogDir 'bridge.out.log'
$NotifyLog = Join-Path $LogDir 'notifications.log'

New-Item -ItemType Directory -Force -Path $StateDir | Out-Null

function Send-Notification([string]$Title, [string]$Message) {
    # Always logged (this is what "check my whatsapp connection" reads back).
    Add-Content -Path $NotifyLog -Value "$(Get-Date -Format o)|$Title|$Message"
    # Best-effort toast via BurntToast (Install-Module BurntToast -Scope CurrentUser).
    # A Scheduled Task can run without an interactive desktop session, where
    # GUI notification APIs throw unpredictably -- keep this best-effort only.
    if (Get-Module -ListAvailable -Name BurntToast) {
        try {
            Import-Module BurntToast -ErrorAction Stop
            New-BurntToastNotification -Text $Title, $Message
        } catch { }
    }
}

function Send-AlertOnce([string]$Key, [string]$Title, [string]$Message) {
    $marker = Join-Path $StateDir "$Key.alerted"
    if (-not (Test-Path $marker)) {
        Send-Notification $Title $Message
        New-Item -ItemType File -Path $marker -Force | Out-Null
    }
}

function Clear-Alert([string]$Key) {
    $marker = Join-Path $StateDir "$Key.alerted"
    Remove-Item -Path $marker -Force -ErrorAction SilentlyContinue
}

$task = Get-ScheduledTask -TaskName $BridgeTaskName -ErrorAction SilentlyContinue
if (-not $task -or $task.State -eq 'Disabled') {
    Send-AlertOnce 'down' 'WhatsApp Bridge Down' 'The bridge scheduled task is not registered or is disabled.'
    exit 0
}
Clear-Alert 'down'

$token = $env:WHATSAPP_BRIDGE_TOKEN
if ([string]::IsNullOrEmpty($token) -and (Test-Path $TokenFile)) {
    $token = (Get-Content -Path $TokenFile -Raw).Trim()
}

if ([string]::IsNullOrEmpty($token)) {
    Send-AlertOnce 'token' 'WhatsApp Bridge Token Missing' "No WHATSAPP_BRIDGE_TOKEN is configured and $TokenFile is unreadable."
    exit 0
}
Clear-Alert 'token'

$apiUrl = $env:WHATSAPP_API_URL.TrimEnd('/')
$headers = @{ Authorization = "Bearer $token" }
$statusCode = $null
$body = $null
try {
    $response = Invoke-WebRequest -Uri "$apiUrl/health" -Headers $headers -TimeoutSec 5 -UseBasicParsing -SkipHttpErrorCheck
    $statusCode = [int]$response.StatusCode
    $body = $response.Content
} catch {
    if ($_.Exception.Response) {
        $statusCode = [int]$_.Exception.Response.StatusCode
        $body = ''
    }
}

if ($null -eq $statusCode) {
    Send-AlertOnce 'api' 'WhatsApp Bridge API Unreachable' "The health endpoint did not respond at $apiUrl/health."
    exit 0
}
if ($statusCode -eq 401 -or $statusCode -eq 403) {
    Send-AlertOnce 'token' 'WhatsApp Bridge Token Invalid' "The health endpoint rejected the configured token. Re-sync WHATSAPP_BRIDGE_TOKEN or $TokenFile."
    exit 0
}
if ($statusCode -ne 200 -and $statusCode -ne 503) {
    Send-AlertOnce 'api' 'WhatsApp Bridge API Unreachable' "Unexpected HTTP $statusCode from $apiUrl/health."
    exit 0
}
Clear-Alert 'api'

$connected = $false
if ($body -match '"connected"\s*:\s*true') {
    $connected = $true
}

if ($connected) {
    Clear-Alert 'relink'
    Clear-Alert 'qr'
} else {
    Send-AlertOnce 'relink' 'WhatsApp Relink Needed' 'The bridge is running but WhatsApp is disconnected. Check logs and scan a QR code if prompted.'
    if (Test-Path $BridgeLog) {
        $tail = Get-Content -Path $BridgeLog -Tail 200 -ErrorAction SilentlyContinue
        if ($tail -match 'Scan this QR code|Device logged out|QR code timed out|Timeout waiting for QR code scan') {
            Send-AlertOnce 'qr' 'WhatsApp QR Action Needed' 'The bridge logs indicate that phone linking is required.'
        } else {
            Clear-Alert 'qr'
        }
    }
}
'@
$monitorContent = $monitorTemplate.Replace('__ENV_FILE__', $EnvFile).Replace('__BRIDGE_TASK_NAME__', $BridgeTaskName)
Set-Content -Path $MonitorScript -Value $monitorContent -Encoding UTF8

# --- hidden-window launcher -------------------------------------------------
# powershell.exe's own -WindowStyle Hidden is unreliable from Task Scheduler:
# conhost.exe allocates a console window before PowerShell can hide it, so a
# window still flashes (or on some builds, never hides at all). Launching
# through a VBScript wrapper via wscript.exe suppresses the window at the
# process-creation level instead, which is reliable.
#
# The trailing "True" makes WScript.Shell.Run BLOCK until the launched
# process exits, so wscript.exe stays alive for exactly as long as the real
# process does (the bridge, effectively forever; the monitor, a few
# seconds). That keeps Task Scheduler's own tracked process matched to the
# actual work's lifetime -- Stop-ScheduledTask/Unregister-ScheduledTask then
# correctly stops/restarts it. Passing False here would let wscript.exe
# launch the child and exit immediately, detaching the real process from
# Task Scheduler's tracking entirely -- fine for the window, but it would
# break the bridge task's whole reason for being a Scheduled Task in the
# first place (auto-restart on crash, clean stop on uninstall/reconnect).
$LauncherScript = Join-Path $SupportDir 'launch-hidden.vbs'
$launcherContent = @'
Set objArgs = WScript.Arguments
scriptPath = objArgs(0)
Set objShell = CreateObject("WScript.Shell")
objShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & scriptPath & """", 0, True
'@
Set-Content -Path $LauncherScript -Value $launcherContent -Encoding ASCII

# --- register scheduled tasks ---------------------------------------------
$settings = New-ScheduledTaskSettingsSet `
    -RestartCount 999 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable

$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

$bridgeAction = New-ScheduledTaskAction -Execute 'wscript.exe' `
    -Argument "`"$LauncherScript`" `"$RunnerScript`""
$bridgeTrigger = New-ScheduledTaskTrigger -AtLogOn

Register-ScheduledTask -TaskName $BridgeTaskName -Action $bridgeAction -Trigger $bridgeTrigger `
    -Settings $settings -Principal $principal -Force | Out-Null
Start-ScheduledTask -TaskName $BridgeTaskName

$monitorAction = New-ScheduledTaskAction -Execute 'wscript.exe' `
    -Argument "`"$LauncherScript`" `"$MonitorScript`""
$monitorTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Seconds 60) -RepetitionDuration (New-TimeSpan -Days 3650)

Register-ScheduledTask -TaskName $MonitorTaskName -Action $monitorAction -Trigger $monitorTrigger `
    -Settings $settings -Principal $principal -Force | Out-Null
Start-ScheduledTask -TaskName $MonitorTaskName

Write-Host "Installed whatsapp-mcp scheduled tasks:"
Write-Host "  $BridgeTaskName"
Write-Host "  $MonitorTaskName"
Write-Host "Logs: $LogDir"
