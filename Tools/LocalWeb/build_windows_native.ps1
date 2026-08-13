[CmdletBinding()]
param(
    [string]$SourceRoot = "",
    [string]$OutputDirectory = ""
)

$ErrorActionPreference = "Stop"

if (-not $IsWindows) {
    throw "The native Windows bundle must be built on Windows."
}
if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne "X64") {
    throw "The current native release target is Windows x86_64."
}

if (-not $SourceRoot) {
    $RepositoryRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    if (Test-Path (Join-Path $PSScriptRoot "app\Package.swift")) {
        $SourceRoot = Join-Path $PSScriptRoot "app"
    } else {
        $SourceRoot = $RepositoryRoot
    }
}
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
if (-not (Test-Path -LiteralPath (Join-Path $SourceRoot "Package.swift") -PathType Leaf)) {
    throw "Package.swift was not found under $SourceRoot."
}
if (-not (Test-Path -LiteralPath (Join-Path $SourceRoot "NavPlanner\Resources\Web\map.html"))) {
    throw "The canonical Web source was not found under $SourceRoot."
}

if (-not (Get-Command swift -ErrorAction SilentlyContinue)) {
    throw "Swift 6.1 or newer is required. Install the official Windows toolchain from swift.org."
}
$SwiftVersion = (& swift --version | Select-Object -First 1)
if ($SwiftVersion -notmatch "Swift version ([0-9]+)\.([0-9]+)") {
    throw "Unable to determine the Swift version: $SwiftVersion"
}
if ([int]$Matches[1] -lt 6 -or ([int]$Matches[1] -eq 6 -and [int]$Matches[2] -lt 1)) {
    throw "Swift 6.1 or newer is required; found $($Matches[1]).$($Matches[2])."
}

$VcpkgRoot = if ($env:VCPKG_INSTALLATION_ROOT) {
    $env:VCPKG_INSTALLATION_ROOT
} elseif (Test-Path "C:\vcpkg\vcpkg.exe") {
    "C:\vcpkg"
} else {
    ""
}
if (-not $VcpkgRoot -or -not (Test-Path (Join-Path $VcpkgRoot "vcpkg.exe"))) {
    throw "vcpkg was not found. Set VCPKG_INSTALLATION_ROOT to a vcpkg checkout."
}

& (Join-Path $VcpkgRoot "vcpkg.exe") install "sqlite3[tool]:x64-windows"
if ($LASTEXITCODE -ne 0) {
    throw "vcpkg failed to install sqlite3[tool]:x64-windows."
}
$Installed = Join-Path $VcpkgRoot "installed\x64-windows"
$IncludeDirectory = Join-Path $Installed "include"
$LibraryDirectory = Join-Path $Installed "lib"
$SQLiteDLL = Join-Path $Installed "bin\sqlite3.dll"
$SQLiteTool = Join-Path $Installed "tools\sqlite3\sqlite3.exe"
if (-not (Test-Path $SQLiteDLL)) {
    throw "vcpkg did not produce $SQLiteDLL."
}
if (-not (Test-Path $SQLiteTool)) {
    throw "vcpkg did not produce the SQLite smoke-test tool at $SQLiteTool."
}

$BuildArguments = @(
    "build", "--package-path", $SourceRoot,
    "--configuration", "release",
    "--product", "simnav-local-web",
    "-Xcc", "-I$IncludeDirectory",
    "-Xlinker", "/LIBPATH:$LibraryDirectory"
)
& swift @BuildArguments
if ($LASTEXITCODE -ne 0) {
    throw "Swift failed to build simnav-local-web.exe."
}
$BinaryDirectory = (& swift build --package-path $SourceRoot --configuration release --show-bin-path).Trim()
$Executable = Join-Path $BinaryDirectory "simnav-local-web.exe"
if (-not (Test-Path $Executable)) {
    throw "The Windows executable was not found at $Executable."
}

if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $SourceRoot "artifacts\SimNavLocalWeb-windows-x86_64"
}
$OutputParent = Split-Path $OutputDirectory -Parent
New-Item -ItemType Directory -Force -Path $OutputParent | Out-Null
if (Test-Path -LiteralPath $OutputDirectory) {
    throw "Output already exists; move it aside explicitly: $OutputDirectory"
}
$StagingDirectory = Join-Path $OutputParent (".simnav-windows-native-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $StagingDirectory | Out-Null

try {
    Copy-Item -LiteralPath $Executable -Destination $StagingDirectory
    Copy-Item -LiteralPath $SQLiteDLL -Destination $StagingDirectory

    $TargetInfo = (& swiftc -print-target-info | ConvertFrom-Json)
    foreach ($RuntimePath in $TargetInfo.paths.runtimeLibraryPaths) {
        if (Test-Path -LiteralPath $RuntimePath) {
            Get-ChildItem -LiteralPath $RuntimePath -Filter "*.dll" -File | ForEach-Object {
                Copy-Item -LiteralPath $_.FullName -Destination $StagingDirectory -Force
            }
        }
    }

    $SmokeRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("SimNavWindowsSmoke-" + [guid]::NewGuid().ToString("N"))
    $SmokeData = Join-Path $SmokeRoot "data"
    New-Item -ItemType Directory -Path $SmokeData | Out-Null
    $FixtureDatabase = Join-Path $SmokeRoot "windows-fixture.s3db"
    @"
CREATE TABLE tbl_header (current_airac TEXT, revision TEXT);
INSERT INTO tbl_header VALUES ('9999', 'windows-native-smoke');
CREATE TABLE tbl_airports (airport_identifier TEXT);
CREATE TABLE tbl_runways (airport_identifier TEXT);
CREATE TABLE tbl_enroute_waypoints (waypoint_identifier TEXT);
CREATE TABLE tbl_enroute_airways (route_identifier TEXT);
"@ | & $SQLiteTool $FixtureDatabase
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $FixtureDatabase)) {
        throw "Unable to create the native Windows database fixture."
    }

    $SmokePort = Get-Random -Minimum 20000 -Maximum 45000
    $SmokeUrl = "http://127.0.0.1:$SmokePort"
    $SmokeToken = "windowsnativebuild0123456789abcdef"
    $PreviousWebRoot = $env:SIMNAV_WEB_ROOT
    $PreviousDataRoot = $env:SIMNAV_DATA_DIR
    $PreviousPort = $env:SIMNAV_WEB_PORT
    $PreviousToken = $env:SIMNAV_WRITE_TOKEN
    $PreviousBindHost = $env:SIMNAV_BIND_HOST
    $PreviousContainer = $env:SIMNAV_CONTAINER
    $SmokeProcess = $null

    function Start-SimNavSmokeServer {
        $Process = Start-Process -FilePath (Join-Path $StagingDirectory "simnav-local-web.exe") `
            -WorkingDirectory $StagingDirectory -NoNewWindow -PassThru
        try {
            $Ready = $false
            foreach ($Attempt in 1..120) {
                if ($Process.HasExited) {
                    throw "Windows smoke server exited with code $($Process.ExitCode)."
                }
                try {
                    $Response = Invoke-WebRequest -Uri "$SmokeUrl/healthz" -TimeoutSec 2
                    if ($Response.StatusCode -eq 200) {
                        $Ready = $true
                        break
                    }
                } catch {
                    Start-Sleep -Milliseconds 500
                }
            }
            if (-not $Ready) {
                throw "The native Windows localhost smoke did not become ready."
            }
            $UnsafeListeners = Get-NetTCPConnection -LocalPort $SmokePort -State Listen -ErrorAction Stop |
                Where-Object { $_.OwningProcess -eq $Process.Id -and $_.LocalAddress -ne "127.0.0.1" }
            if ($UnsafeListeners) {
                throw "The native Windows server listened outside 127.0.0.1."
            }
            return $Process
        } catch {
            if (-not $Process.HasExited) {
                Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
                $Process.WaitForExit(5000) | Out-Null
            }
            throw
        }
    }

    function Stop-SimNavSmokeServer([System.Diagnostics.Process]$Process) {
        if ($Process -and -not $Process.HasExited) {
            Stop-Process -Id $Process.Id -ErrorAction SilentlyContinue
            $Process.WaitForExit(5000) | Out-Null
        }
        if ($Process -and -not $Process.HasExited) {
            Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
            $Process.WaitForExit(5000) | Out-Null
        }
    }

    try {
        $env:SIMNAV_WEB_ROOT = Join-Path $SourceRoot "NavPlanner\Resources\Web"
        $env:SIMNAV_DATA_DIR = $SmokeData
        $env:SIMNAV_WEB_PORT = "$SmokePort"
        $env:SIMNAV_WRITE_TOKEN = $SmokeToken
        $env:SIMNAV_BIND_HOST = "127.0.0.1"
        $env:SIMNAV_CONTAINER = $null
        $SmokeProcess = Start-SimNavSmokeServer

        $ImportResponse = Invoke-WebRequest -Uri "$SmokeUrl/api/databases/import" `
            -Method Post -InFile $FixtureDatabase -ContentType "application/octet-stream" `
            -Headers @{
                "Origin" = $SmokeUrl
                "X-SimNav-Filename" = "windows-fixture.s3db"
                "X-SimNav-Token" = $SmokeToken
            } -TimeoutSec 30
        $ImportPayload = $ImportResponse.Content | ConvertFrom-Json
        if ($ImportResponse.StatusCode -ne 200 -or
            $ImportPayload.local_status -ne "ready" -or
            $ImportPayload.database_name -ne "windows_fixture.sqlite") {
            throw "Native Windows database import did not activate the fixture."
        }

        Stop-SimNavSmokeServer $SmokeProcess
        $SmokeProcess = $null
        $SmokeProcess = Start-SimNavSmokeServer
        $HeaderResponse = Invoke-WebRequest -Uri "$SmokeUrl/api/header" -TimeoutSec 10
        $HeaderPayload = $HeaderResponse.Content | ConvertFrom-Json
        if ($HeaderResponse.StatusCode -ne 200 -or
            $HeaderPayload.current_airac -ne "9999" -or
            $HeaderPayload.revision -ne "windows-native-smoke" -or
            $HeaderPayload.database_name -ne "windows_fixture.sqlite") {
            throw "Native Windows database selection did not survive a server restart."
        }
    } finally {
        Stop-SimNavSmokeServer $SmokeProcess
        $env:SIMNAV_WEB_ROOT = $PreviousWebRoot
        $env:SIMNAV_DATA_DIR = $PreviousDataRoot
        $env:SIMNAV_WEB_PORT = $PreviousPort
        $env:SIMNAV_WRITE_TOKEN = $PreviousToken
        $env:SIMNAV_BIND_HOST = $PreviousBindHost
        $env:SIMNAV_CONTAINER = $PreviousContainer
        if (Test-Path -LiteralPath $SmokeRoot) {
            Remove-Item -LiteralPath $SmokeRoot -Recurse -Force
        }
    }

    @(
        "swift=$SwiftVersion",
        "target=windows-x86_64",
        "http_transport=swift-nio-2.101.3",
        "smoke=health,loopback,database-import,restart-persistence:passed"
    ) | Set-Content -LiteralPath (Join-Path $StagingDirectory "BUILD-INFO.txt") -Encoding utf8
    Move-Item -LiteralPath $StagingDirectory -Destination $OutputDirectory
} catch {
    if (Test-Path -LiteralPath $StagingDirectory) {
        Remove-Item -LiteralPath $StagingDirectory -Recurse -Force
    }
    throw
}

Write-Host "Native Windows Local Web bundle: $OutputDirectory"
