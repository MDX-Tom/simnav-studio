[CmdletBinding()]
param(
    [string]$BridgeScript = (Join-Path $PSScriptRoot "release\fr24-browser-bridge.ps1")
)

$ErrorActionPreference = "Stop"

function Get-EphemeralPort {
    $Listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $Listener.Start()
    try {
        return ([System.Net.IPEndPoint]$Listener.LocalEndpoint).Port
    } finally {
        $Listener.Stop()
    }
}

$TargetPort = Get-EphemeralPort
$BridgePort = Get-EphemeralPort
while ($BridgePort -eq $TargetPort) { $BridgePort = Get-EphemeralPort }
$Token = "bridgecontract0123456789abcdef"
$Root = Join-Path ([System.IO.Path]::GetTempPath()) ("SimNavFR24Bridge-" + [guid]::NewGuid().ToString("N"))
$ReadyFile = Join-Path $Root "ready"
New-Item -ItemType Directory -Path $Root | Out-Null

$TargetJob = Start-Job -ArgumentList $TargetPort -ScriptBlock {
    param([int]$Port)
    $Listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
    $Listener.Start(4)
    try {
        $Client = $Listener.AcceptTcpClient()
        try {
            $Stream = $Client.GetStream()
            $Bytes = [System.Collections.Generic.List[byte]]::new()
            while ($Bytes.Count -lt 65536) {
                $Value = $Stream.ReadByte()
                if ($Value -lt 0) { break }
                $Bytes.Add([byte]$Value)
                $Count = $Bytes.Count
                if ($Count -ge 4 -and
                    $Bytes[$Count - 4] -eq 13 -and $Bytes[$Count - 3] -eq 10 -and
                    $Bytes[$Count - 2] -eq 13 -and $Bytes[$Count - 1] -eq 10) {
                    break
                }
            }
            $Header = [System.Text.Encoding]::ASCII.GetString($Bytes.ToArray())
            $Host = (($Header -split "`r`n") | Where-Object { $_ -match '^(?i:Host):' } | Select-Object -First 1)
            $HasToken = $Header -match '^(?im:X-CDP-Token):'
            $HasClose = $Header -match '^(?im:Connection):\s*close\s*$'
            $Payload = [ordered]@{
                'Protocol-Version' = '1.3'
                host = $Host
                token_forwarded = $HasToken
                connection_close = $HasClose
            } | ConvertTo-Json -Compress
            $Body = [System.Text.Encoding]::UTF8.GetBytes($Payload)
            $Head = [System.Text.Encoding]::ASCII.GetBytes(
                "HTTP/1.1 200 OK`r`nContent-Type: application/json`r`nContent-Length: $($Body.Length)`r`nConnection: close`r`n`r`n"
            )
            $Stream.Write($Head, 0, $Head.Length)
            $Stream.Write($Body, 0, $Body.Length)
            $Stream.Flush()
        } finally {
            $Client.Dispose()
        }
    } finally {
        $Listener.Stop()
    }
}

$BridgeProcess = $null
try {
    if (-not (Test-Path -LiteralPath $BridgeScript -PathType Leaf)) {
        throw "Bridge script not found: $BridgeScript"
    }
    $env:SIMNAV_FR24_CDP_TOKEN = $Token
    $PowerShellExecutable = (Get-Process -Id $PID).Path
    $Arguments = @(
        "-NoLogo", "-NoProfile", "-NonInteractive",
        "-File", "`"$BridgeScript`"",
        "-ListenPort", "$BridgePort",
        "-TargetPort", "$TargetPort",
        "-ReadyFile", "`"$ReadyFile`""
    )
    $BridgeProcess = Start-Process -FilePath $PowerShellExecutable -ArgumentList $Arguments -PassThru
    foreach ($Attempt in 1..100) {
        if ($BridgeProcess.HasExited) {
            throw "Bridge exited during contract smoke."
        }
        if (Test-Path -LiteralPath $ReadyFile -PathType Leaf) { break }
        Start-Sleep -Milliseconds 100
    }
    if (-not (Test-Path -LiteralPath $ReadyFile -PathType Leaf)) {
        throw "Bridge did not become ready during contract smoke."
    }

    $UnauthorizedStatus = 0
    try {
        Invoke-WebRequest -Uri "http://127.0.0.1:$BridgePort/json/version" -TimeoutSec 3 | Out-Null
    } catch {
        $UnauthorizedStatus = [int]$_.Exception.Response.StatusCode
    }
    if ($UnauthorizedStatus -ne 403) {
        throw "Bridge returned $UnauthorizedStatus without its token; expected 403."
    }

    $Payload = Invoke-RestMethod -Uri "http://127.0.0.1:$BridgePort/json/version" `
        -Headers @{ "X-CDP-Token" = $Token } -TimeoutSec 3
    if ($Payload.'Protocol-Version' -ne "1.3" -or
        $Payload.host -ne "Host: 127.0.0.1:$TargetPort" -or
        $Payload.token_forwarded -ne $false -or
        $Payload.connection_close -ne $true) {
        throw "Bridge did not preserve its authentication/forwarding contract: $($Payload | ConvertTo-Json -Compress)"
    }
    Write-Host "FR24_BROWSER_BRIDGE_CONTRACT=PASS"
} finally {
    if ($BridgeProcess -and -not $BridgeProcess.HasExited) {
        Stop-Process -Id $BridgeProcess.Id -Force -ErrorAction SilentlyContinue
        $BridgeProcess.WaitForExit(5000) | Out-Null
    }
    Stop-Job $TargetJob -ErrorAction SilentlyContinue
    Remove-Job $TargetJob -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $Root -Recurse -Force -ErrorAction SilentlyContinue
}
