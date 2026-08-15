[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$Port = if ($env:SIMNAV_WEB_PORT) { [int]$env:SIMNAV_WEB_PORT } else { 8010 }
if ($Port -lt 1 -or $Port -gt 65535) {
    throw "SIMNAV_WEB_PORT must be between 1 and 65535."
}

$Url = "http://127.0.0.1:$Port"
$NativeExe = Join-Path $PSScriptRoot "native\windows-x86_64\simnav-local-web.exe"
$WebRoot = Join-Path $PSScriptRoot "app\NavPlanner\Resources\Web"
$BundledDatabase = Join-Path $PSScriptRoot "app\NavPlanner\Resources\Database\navdata.sqlite"
$StateRoot = Join-Path $env:LOCALAPPDATA "SimNav Studio Web\Runtime"
$FR24ProfileRoot = Join-Path $env:LOCALAPPDATA "SimNav Studio Web\FR24Browser"
$PidFile = Join-Path $StateRoot "server-$Port.pid"
$BridgeStateFile = Join-Path $StateRoot "fr24-docker-$Port.json"
$BridgeReadyFile = Join-Path $StateRoot "fr24-docker-$Port.ready"
$BridgeScript = Join-Path $PSScriptRoot "fr24-browser-bridge.ps1"
$PortBusy = $null -ne (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
    Select-Object -First 1)

function Get-ProcessCommandLine([int]$ProcessId) {
    $Entry = Get-CimInstance Win32_Process -Filter "ProcessId = $ProcessId" -ErrorAction SilentlyContinue
    if ($Entry) { return [string]$Entry.CommandLine }
    return ""
}

function Test-OwnedBrowserProcess([int]$ProcessId) {
    if ($ProcessId -le 0 -or -not (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)) {
        return $false
    }
    $CommandLine = Get-ProcessCommandLine $ProcessId
    return $CommandLine.Contains("--remote-debugging-port") -and
        $CommandLine.Contains($FR24ProfileRoot)
}

function Test-OwnedBridgeProcess([int]$ProcessId) {
    if ($ProcessId -le 0 -or -not (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)) {
        return $false
    }
    return (Get-ProcessCommandLine $ProcessId).Contains($BridgeScript)
}

function Stop-OwnedProcess([int]$ProcessId, [scriptblock]$OwnershipCheck) {
    if ($ProcessId -gt 0 -and (& $OwnershipCheck $ProcessId)) {
        Stop-Process -Id $ProcessId -ErrorAction SilentlyContinue
        $Process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
        if ($Process) {
            $Process.WaitForExit(5000) | Out-Null
        }
        if (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue) {
            Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
        }
    }
}

function Get-AvailableTCPPort {
    foreach ($Attempt in 1..100) {
        $Candidate = Get-Random -Minimum 22000 -Maximum 55000
        if ($Candidate -ne $Port -and -not (Get-NetTCPConnection -LocalPort $Candidate -State Listen -ErrorAction SilentlyContinue)) {
            return $Candidate
        }
    }
    throw "Unable to reserve a local port for the FR24 browser bridge."
}

function New-RandomToken {
    $Bytes = New-Object byte[] 32
    $Generator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $Generator.GetBytes($Bytes)
    } finally {
        $Generator.Dispose()
    }
    return ([System.BitConverter]::ToString($Bytes)).Replace("-", "").ToLowerInvariant()
}

function Clear-RestoredFR24Tabs {
    # Keep FR24/Cloudflare site data in the isolated profile while avoiding
    # stale raw JSON or challenge tabs after a previous server has stopped.
    $DefaultProfile = Join-Path $FR24ProfileRoot "Default"
    @("Sessions", "Current Session", "Current Tabs", "Last Session", "Last Tabs") |
        ForEach-Object {
            Remove-Item -LiteralPath (Join-Path $DefaultProfile $_) -Recurse -Force -ErrorAction SilentlyContinue
        }
}

function Find-FR24Browser {
    if ($env:SIMNAV_FR24_BROWSER) {
        if (-not (Test-Path -LiteralPath $env:SIMNAV_FR24_BROWSER -PathType Leaf)) {
            throw "SIMNAV_FR24_BROWSER does not exist: $($env:SIMNAV_FR24_BROWSER)"
        }
        return (Resolve-Path -LiteralPath $env:SIMNAV_FR24_BROWSER).Path
    }
    $Candidates = @(
        (Join-Path $env:ProgramFiles "Google\Chrome\Application\chrome.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Google\Chrome\Application\chrome.exe"),
        (Join-Path $env:LOCALAPPDATA "Google\Chrome\Application\chrome.exe"),
        (Join-Path $env:ProgramFiles "Chromium\Application\chrome.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Chromium\Application\chrome.exe"),
        (Join-Path $env:LOCALAPPDATA "Chromium\Application\chrome.exe"),
        (Join-Path $env:ProgramFiles "Microsoft\Edge\Application\msedge.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Microsoft\Edge\Application\msedge.exe")
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) }
    if (-not $Candidates) {
        throw "Microsoft Edge, Google Chrome, or Chromium is required for the App-equivalent FR24 workflow."
    }
    return $Candidates[0]
}

function Test-BrowserEndpoint([int]$BrowserPort) {
    if ($BrowserPort -lt 1 -or $BrowserPort -gt 65535) { return $false }
    try {
        $Version = Invoke-RestMethod -Uri "http://127.0.0.1:$BrowserPort/json/version" -TimeoutSec 2
        return $null -ne $Version.'Protocol-Version'
    } catch {
        return $false
    }
}

if (Test-Path -LiteralPath $NativeExe -PathType Leaf) {
    if (-not (Test-Path -LiteralPath $BundledDatabase -PathType Leaf)) {
        throw "The bundled navigation database is missing: $BundledDatabase"
    }
    if ($PortBusy) {
        throw "Port $Port is already in use; nothing was changed."
    }
    $env:SIMNAV_WEB_PORT = "$Port"
    $env:SIMNAV_WEB_ROOT = $WebRoot
    $env:SIMNAV_DATABASE = $BundledDatabase
    New-Item -ItemType Directory -Force -Path $StateRoot | Out-Null
    $Process = Start-Process -FilePath $NativeExe -WorkingDirectory (Split-Path $NativeExe) `
        -NoNewWindow -PassThru
    Set-Content -LiteralPath $PidFile -Value $Process.Id -Encoding ascii
    try {
        $Ready = $false
        foreach ($Attempt in 1..120) {
            if ($Process.HasExited) {
                throw "The native Windows server exited with code $($Process.ExitCode)."
            }
            try {
                $Response = Invoke-WebRequest -Uri "$Url/healthz" -TimeoutSec 2
                if ($Response.StatusCode -eq 200) {
                    $Ready = $true
                    break
                }
            } catch {
                Start-Sleep -Milliseconds 500
            }
        }
        if (-not $Ready) {
            throw "SimNav Studio Local Web did not become ready at $Url."
        }
        Write-Host "SimNav Studio Local Web is running as a native Windows process: $Url"
        Start-Process $Url
        Write-Host "Keep this window open; press Control-C to stop the native server."
        $Process.WaitForExit()
        exit $Process.ExitCode
    } finally {
        if (-not $Process.HasExited) {
            Stop-Process -Id $Process.Id -ErrorAction SilentlyContinue
        }
        if (Test-Path -LiteralPath $PidFile) {
            $RecordedPid = (Get-Content -LiteralPath $PidFile -Raw).Trim()
            if ($RecordedPid -eq "$($Process.Id)") {
                Remove-Item -LiteralPath $PidFile -Force
            }
        }
    }
}

Write-Host "A native Windows bundle is not included; using Docker with a background managed Chrome/Chromium/Edge session."
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Install Docker Desktop, or add native\windows-x86_64\simnav-local-web.exe and its DLLs."
}
if (-not (Test-Path -LiteralPath $BridgeScript -PathType Leaf)) {
    throw "The FR24 host bridge is missing: $BridgeScript"
}
docker compose version | Out-Null
docker info | Out-Null
New-Item -ItemType Directory -Force -Path $StateRoot, $FR24ProfileRoot | Out-Null

$BrowserPid = 0
$BrowserPort = 0
$BridgePid = 0
$StartupComplete = $false

try {
    if (Test-Path -LiteralPath $BridgeStateFile -PathType Leaf) {
        try {
            $OldState = Get-Content -LiteralPath $BridgeStateFile -Raw | ConvertFrom-Json
            if ($OldState.bridge_pid) {
                Stop-OwnedProcess ([int]$OldState.bridge_pid) ${function:Test-OwnedBridgeProcess}
            }
            if ($OldState.browser_pid -and $OldState.browser_port -and
                (Test-OwnedBrowserProcess ([int]$OldState.browser_pid)) -and
                (Test-BrowserEndpoint ([int]$OldState.browser_port))) {
                $BrowserPid = [int]$OldState.browser_pid
                $BrowserPort = [int]$OldState.browser_port
            }
        } catch {
            # Stale state is ignored; ownership checks still guard every stop.
        }
    }

    if ($BrowserPort -eq 0) {
        $BrowserExecutable = Find-FR24Browser
        Clear-RestoredFR24Tabs
        Remove-Item -LiteralPath (Join-Path $FR24ProfileRoot "DevToolsActivePort") `
            -Force -ErrorAction SilentlyContinue
        $BrowserPort = Get-AvailableTCPPort
        $BrowserArguments = @(
            "--remote-debugging-port=$BrowserPort",
            "--remote-debugging-address=127.0.0.1",
            "--user-data-dir=`"$FR24ProfileRoot`"",
            "--no-first-run",
            "--no-default-browser-check",
            "--disable-sync",
            "--disable-background-mode",
            "--no-startup-window",
            "--window-position=-10000,-10000",
            "--window-size=1280,900"
        )
        $BrowserProcess = Start-Process -FilePath $BrowserExecutable `
            -ArgumentList $BrowserArguments -PassThru
        $BrowserPid = $BrowserProcess.Id
        foreach ($Attempt in 1..150) {
            if (Test-BrowserEndpoint $BrowserPort) {
                $Owner = Get-NetTCPConnection -LocalPort $BrowserPort -State Listen -ErrorAction SilentlyContinue |
                    Where-Object { $_.LocalAddress -eq "127.0.0.1" } |
                    Select-Object -First 1
                if ($Owner -and (Test-OwnedBrowserProcess ([int]$Owner.OwningProcess))) {
                    $BrowserPid = [int]$Owner.OwningProcess
                }
                break
            }
            if ($BrowserProcess.HasExited -and -not (Test-OwnedBrowserProcess $BrowserPid)) {
                throw "The dedicated FR24 browser exited during startup."
            }
            Start-Sleep -Milliseconds 100
        }
        if (-not (Test-BrowserEndpoint $BrowserPort)) {
            $BrowserPort = 0
            throw "The dedicated FR24 browser did not expose its loopback session."
        }
    }

    $BridgePort = Get-AvailableTCPPort
    $BridgeToken = New-RandomToken
    $env:SIMNAV_FR24_CDP_TOKEN = $BridgeToken
    Remove-Item -LiteralPath $BridgeReadyFile -Force -ErrorAction SilentlyContinue
    $PowerShellExecutable = (Get-Process -Id $PID).Path
    $BridgeArguments = @(
        "-NoLogo", "-NoProfile", "-NonInteractive",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$BridgeScript`"",
        "-ListenPort", "$BridgePort",
        "-TargetPort", "$BrowserPort",
        "-ReadyFile", "`"$BridgeReadyFile`""
    )
    $BridgeProcess = Start-Process -FilePath $PowerShellExecutable `
        -ArgumentList $BridgeArguments -WindowStyle Hidden -PassThru
    $BridgePid = $BridgeProcess.Id
    foreach ($Attempt in 1..100) {
        if ($BridgeProcess.HasExited) {
            throw "The FR24 browser bridge exited during startup."
        }
        if (Test-Path -LiteralPath $BridgeReadyFile -PathType Leaf) {
            break
        }
        Start-Sleep -Milliseconds 100
    }
    if (-not (Test-Path -LiteralPath $BridgeReadyFile -PathType Leaf)) {
        throw "The FR24 browser bridge did not become ready."
    }
    $BridgeVersion = Invoke-RestMethod -Uri "http://127.0.0.1:$BridgePort/json/version" `
        -Headers @{ "X-CDP-Token" = $BridgeToken } -TimeoutSec 3
    if (-not $BridgeVersion.'Protocol-Version') {
        throw "The FR24 browser bridge failed its authenticated control probe."
    }

    $env:SIMNAV_WEB_PORT = "$Port"
    $env:SIMNAV_WEB_VERSION = if ($env:SIMNAV_WEB_VERSION) { $env:SIMNAV_WEB_VERSION } else { "local" }
    $env:SIMNAV_FR24_CDP_ENDPOINT = "http://host.docker.internal:$BridgePort"
    $env:SIMNAV_FR24_CDP_TOKEN = $BridgeToken
    [pscustomobject]@{
        browser_pid = $BrowserPid
        browser_port = $BrowserPort
        bridge_pid = $BridgePid
        bridge_port = $BridgePort
    } | ConvertTo-Json | Set-Content -LiteralPath $BridgeStateFile -Encoding utf8

    Push-Location $PSScriptRoot
    try {
        $ExistingContainer = docker compose ps --quiet simnav-web
        if ($PortBusy -and -not $ExistingContainer) {
            throw "Port $Port is already in use by another process; nothing was changed."
        }
        docker compose up --detach --build
        $Ready = $false
        foreach ($Attempt in 1..180) {
            docker compose exec --no-TTY simnav-web `
                curl --fail --silent "http://127.0.0.1:$Port/healthz" 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $Ready = $true
                break
            }
            Start-Sleep -Seconds 1
        }
        if (-not $Ready) {
            docker compose logs --tail=100 simnav-web
            throw "SimNav Studio Local Web did not become ready."
        }
    } finally {
        Pop-Location
    }

    $BrowserStatus = Invoke-RestMethod -Uri "$Url/api/fr24/browser/status" -TimeoutSec 5
    if ($BrowserStatus.browser_adapter_available -ne $true -or $BrowserStatus.browser_running -ne $true) {
        throw "The Local Web container could not reach its dedicated FR24 browser."
    }
    $StartupComplete = $true
} finally {
    if (-not $StartupComplete) {
        Push-Location $PSScriptRoot
        try { docker compose down 2>$null | Out-Null } catch { }
        finally { Pop-Location }
        Stop-OwnedProcess $BridgePid ${function:Test-OwnedBridgeProcess}
        Stop-OwnedProcess $BrowserPid ${function:Test-OwnedBrowserProcess}
        Remove-Item -LiteralPath $BridgeReadyFile, $BridgeStateFile -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "SimNav Studio Local Web is ready in Docker with its managed FR24 browser: $Url"
Start-Process $Url
Write-Host "The container and dedicated browser stay active after this window closes. Run stop-windows.ps1 to stop them."
