$ErrorActionPreference = "Stop"
$Port = if ($env:SIMNAV_WEB_PORT) { [int]$env:SIMNAV_WEB_PORT } else { 8010 }
$NativeExe = Join-Path $PSScriptRoot "native\windows-x86_64\simnav-local-web.exe"
$StateRoot = Join-Path $env:LOCALAPPDATA "SimNav Studio Web\Runtime"
$FR24ProfileRoot = Join-Path $env:LOCALAPPDATA "SimNav Studio Web\FR24Browser"
$PidFile = Join-Path $StateRoot "server-$Port.pid"
$BridgeStateFile = Join-Path $StateRoot "fr24-docker-$Port.json"
$BridgeReadyFile = Join-Path $StateRoot "fr24-docker-$Port.ready"
$BridgeScript = Join-Path $PSScriptRoot "fr24-browser-bridge.ps1"

function Get-ProcessCommandLine([int]$ProcessId) {
    $Entry = Get-CimInstance Win32_Process -Filter "ProcessId = $ProcessId" -ErrorAction SilentlyContinue
    if ($Entry) { return [string]$Entry.CommandLine }
    return ""
}

function Stop-VerifiedProcess([int]$ProcessId, [string]$RequiredCommandLineText) {
    if ($ProcessId -le 0) { return }
    $Process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if (-not $Process) { return }
    $CommandLine = Get-ProcessCommandLine $ProcessId
    if (-not $CommandLine.Contains($RequiredCommandLineText)) {
        throw "Refusing to stop PID $ProcessId because it is not the recorded SimNav process."
    }
    Stop-Process -Id $ProcessId -ErrorAction SilentlyContinue
    $Process.WaitForExit(5000) | Out-Null
    if (-not $Process.HasExited) {
        Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
    }
}

if (Test-Path -LiteralPath $PidFile) {
    $RecordedPid = (Get-Content -LiteralPath $PidFile -Raw).Trim()
    if ($RecordedPid -match "^[0-9]+$") {
        $NativeProcess = Get-Process -Id ([int]$RecordedPid) -ErrorAction SilentlyContinue
        if ($NativeProcess) {
            $ExpectedPath = [System.IO.Path]::GetFullPath($NativeExe)
            $ActualPath = $NativeProcess.Path
            if (-not $ActualPath -or [System.IO.Path]::GetFullPath($ActualPath) -ne $ExpectedPath) {
                throw "Refusing to stop PID $RecordedPid because it is not this SimNav native server."
            }
            Stop-Process -Id $NativeProcess.Id
            $NativeProcess.WaitForExit(5000) | Out-Null
            if (-not $NativeProcess.HasExited) {
                throw "Native SimNav server did not stop within five seconds."
            }
            Remove-Item -LiteralPath $PidFile -Force
            Write-Host "SimNav Studio native Local Web stopped. Its data was preserved."
            exit 0
        }
    }
    Remove-Item -LiteralPath $PidFile -Force
}

$BrowserPid = 0
$BridgePid = 0
if (Test-Path -LiteralPath $BridgeStateFile -PathType Leaf) {
    try {
        $State = Get-Content -LiteralPath $BridgeStateFile -Raw | ConvertFrom-Json
        $BrowserPid = if ($State.browser_pid) { [int]$State.browser_pid } else { 0 }
        $BridgePid = if ($State.bridge_pid) { [int]$State.bridge_pid } else { 0 }
    } catch {
        throw "The Local Web FR24 process record is invalid: $BridgeStateFile"
    }
}

Stop-VerifiedProcess $BridgePid $BridgeScript

if (Get-Command docker -ErrorAction SilentlyContinue) {
    Push-Location $PSScriptRoot
    try {
        docker compose down
    } finally {
        Pop-Location
    }
}

if ($BrowserPid -gt 0) {
    $BrowserCommandLine = Get-ProcessCommandLine $BrowserPid
    if ((Get-Process -Id $BrowserPid -ErrorAction SilentlyContinue) -and
        (-not $BrowserCommandLine.Contains("--remote-debugging-port") -or
         -not $BrowserCommandLine.Contains($FR24ProfileRoot))) {
        throw "Refusing to stop PID $BrowserPid because it is not the isolated SimNav browser."
    }
    Stop-VerifiedProcess $BrowserPid $FR24ProfileRoot
}

Remove-Item -LiteralPath $BridgeReadyFile, $BridgeStateFile -Force -ErrorAction SilentlyContinue
Write-Host "SimNav Studio Local Web and its dedicated FR24 browser stopped. Data, downloads, and the isolated profile were preserved."
