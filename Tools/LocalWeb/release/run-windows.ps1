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
$StateRoot = Join-Path $env:LOCALAPPDATA "SimNav Studio Web\Runtime"
$PidFile = Join-Path $StateRoot "server-$Port.pid"
$PortBusy = $null -ne (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
    Select-Object -First 1)

if (Test-Path -LiteralPath $NativeExe -PathType Leaf) {
    if ($PortBusy) {
        throw "Port $Port is already in use; nothing was changed."
    }
    $env:SIMNAV_WEB_PORT = "$Port"
    $env:SIMNAV_WEB_ROOT = $WebRoot
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

Write-Host "A native Windows bundle is not included; using the Docker fallback."
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Install Docker Desktop, or add native\windows-x86_64\simnav-local-web.exe and its DLLs."
}
docker compose version | Out-Null
docker info | Out-Null
$env:SIMNAV_WEB_PORT = "$Port"
$env:SIMNAV_WEB_VERSION = if ($env:SIMNAV_WEB_VERSION) { $env:SIMNAV_WEB_VERSION } else { "local" }
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
Write-Host "SimNav Studio Local Web is ready in Docker: $Url"
Start-Process $Url
Write-Host "The container stays active after this window closes. Run stop-windows.ps1 to stop it."
