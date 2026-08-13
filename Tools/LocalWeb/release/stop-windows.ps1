$ErrorActionPreference = "Stop"
$Port = if ($env:SIMNAV_WEB_PORT) { [int]$env:SIMNAV_WEB_PORT } else { 8010 }
$NativeExe = Join-Path $PSScriptRoot "native\windows-x86_64\simnav-local-web.exe"
$StateRoot = Join-Path $env:LOCALAPPDATA "SimNav Studio Web\Runtime"
$PidFile = Join-Path $StateRoot "server-$Port.pid"

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

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "No recorded native server is running, and Docker is unavailable."
    exit 0
}
Push-Location $PSScriptRoot
try {
    docker compose down
} finally {
    Pop-Location
}
Write-Host "SimNav Studio Local Web stopped. Its Docker data volume was preserved."
