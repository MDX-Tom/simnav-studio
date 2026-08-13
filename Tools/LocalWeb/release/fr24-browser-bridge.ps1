[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1024, 65535)]
    [int]$ListenPort,

    [Parameter(Mandatory = $true)]
    [ValidateRange(1024, 65535)]
    [int]$TargetPort,

    [ValidateLength(16, 256)]
    [string]$Token = $env:SIMNAV_FR24_CDP_TOKEN,

    [Parameter(Mandatory = $true)]
    [string]$ReadyFile
)

$ErrorActionPreference = "Stop"
if (-not $Token) {
    throw "SIMNAV_FR24_CDP_TOKEN is required."
}

function Test-FixedTimeToken([string]$Left, [string]$Right) {
    $LeftBytes = [System.Text.Encoding]::UTF8.GetBytes($Left)
    $RightBytes = [System.Text.Encoding]::UTF8.GetBytes($Right)
    $Difference = $LeftBytes.Length -bxor $RightBytes.Length
    $Count = [Math]::Max($LeftBytes.Length, $RightBytes.Length)
    for ($Index = 0; $Index -lt $Count; $Index++) {
        $LeftByte = if ($Index -lt $LeftBytes.Length) { $LeftBytes[$Index] } else { 0 }
        $RightByte = if ($Index -lt $RightBytes.Length) { $RightBytes[$Index] } else { 0 }
        $Difference = $Difference -bor ($LeftByte -bxor $RightByte)
    }
    return $Difference -eq 0
}

function Read-HTTPHeader([System.Net.Sockets.NetworkStream]$Stream) {
    $Bytes = [System.Collections.Generic.List[byte]]::new()
    while ($Bytes.Count -lt 65536) {
        $Value = $Stream.ReadByte()
        if ($Value -lt 0) {
            return $null
        }
        $Bytes.Add([byte]$Value)
        $Count = $Bytes.Count
        if ($Count -ge 4 -and
            $Bytes[$Count - 4] -eq 13 -and
            $Bytes[$Count - 3] -eq 10 -and
            $Bytes[$Count - 2] -eq 13 -and
            $Bytes[$Count - 1] -eq 10) {
            return ,([byte[]]$Bytes.ToArray())
        }
    }
    throw "The browser-control request header exceeded 64 KiB."
}

function Write-HTTPError(
    [System.Net.Sockets.NetworkStream]$Stream,
    [int]$Status,
    [string]$Reason
) {
    $Body = "Browser bridge rejected the request."
    $Response = "HTTP/1.1 $Status $Reason`r`nContent-Type: text/plain; charset=utf-8`r`nContent-Length: $([System.Text.Encoding]::UTF8.GetByteCount($Body))`r`nConnection: close`r`n`r`n$Body"
    $Data = [System.Text.Encoding]::UTF8.GetBytes($Response)
    $Stream.Write($Data, 0, $Data.Length)
    $Stream.Flush()
}

function Convert-AuthorizedHeader([byte[]]$HeaderBytes) {
    $HeaderText = [System.Text.Encoding]::ASCII.GetString($HeaderBytes)
    $Lines = $HeaderText -split "`r`n"
    $ProvidedToken = ""
    $IsWebSocket = $false
    foreach ($Line in $Lines) {
        if ($Line -match '^(?i:X-CDP-Token):\s*(.*)$') {
            $ProvidedToken = $Matches[1].Trim()
        }
        if ($Line -match '^(?i:Upgrade):\s*websocket\s*$') {
            $IsWebSocket = $true
        }
    }
    if (-not (Test-FixedTimeToken $ProvidedToken $Token)) {
        return $null
    }

    $Output = [System.Collections.Generic.List[string]]::new()
    $ConnectionWritten = $false
    foreach ($Line in $Lines) {
        if ($Line -match '^(?i:X-CDP-Token):') {
            continue
        }
        if ($Line -match '^(?i:Host):') {
            $Output.Add("Host: 127.0.0.1:$TargetPort")
            continue
        }
        if ($Line -match '^(?i:Origin):') {
            $Output.Add("Origin: http://127.0.0.1:$TargetPort")
            continue
        }
        if (-not $IsWebSocket -and $Line -match '^(?i:Connection):') {
            if (-not $ConnectionWritten) {
                $Output.Add("Connection: close")
                $ConnectionWritten = $true
            }
            continue
        }
        $Output.Add($Line)
    }
    if (-not $IsWebSocket -and -not $ConnectionWritten) {
        $Output.Insert([Math]::Max(1, $Output.Count - 2), "Connection: close")
    }
    return ,([byte[]][System.Text.Encoding]::ASCII.GetBytes(($Output -join "`r`n")))
}

$ReadyDirectory = Split-Path -Parent $ReadyFile
New-Item -ItemType Directory -Force -Path $ReadyDirectory | Out-Null
$Listener = [System.Net.Sockets.TcpListener]::new(
    [System.Net.IPAddress]::Any,
    $ListenPort
)
$Listener.Start(16)
Set-Content -LiteralPath $ReadyFile -Value "$PID" -Encoding ascii

try {
    while ($true) {
        $Client = $Listener.AcceptTcpClient()
        $Target = $null
        try {
            $Client.NoDelay = $true
            $Client.ReceiveTimeout = 15000
            $Client.SendTimeout = 15000
            $ClientStream = $Client.GetStream()
            $Header = Read-HTTPHeader $ClientStream
            if (-not $Header) {
                continue
            }
            $AuthorizedHeader = Convert-AuthorizedHeader $Header
            if (-not $AuthorizedHeader) {
                Write-HTTPError $ClientStream 403 "Forbidden"
                continue
            }

            $Target = [System.Net.Sockets.TcpClient]::new()
            $Target.NoDelay = $true
            $Target.Connect([System.Net.IPAddress]::Loopback, $TargetPort)
            $TargetStream = $Target.GetStream()
            $TargetStream.Write($AuthorizedHeader, 0, $AuthorizedHeader.Length)
            $TargetStream.Flush()

            $ClientToTarget = $ClientStream.CopyToAsync($TargetStream)
            $TargetToClient = $TargetStream.CopyToAsync($ClientStream)
            [System.Threading.Tasks.Task]::WaitAny(
                [System.Threading.Tasks.Task[]]@($ClientToTarget, $TargetToClient)
            ) | Out-Null
        } catch {
            # A browser tab closing normally tears down one side of the socket.
            # The bridge carries no response bodies into logs.
        } finally {
            if ($Target) { $Target.Dispose() }
            $Client.Dispose()
        }
    }
} finally {
    $Listener.Stop()
    if (Test-Path -LiteralPath $ReadyFile) {
        Remove-Item -LiteralPath $ReadyFile -Force
    }
}
