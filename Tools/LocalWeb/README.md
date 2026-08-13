# SimNav Studio Local Web development server

Run the native localhost server from any working directory:

```bash
Tools/LocalWeb/run.sh [options]
```

Options:

```text
--port <port>          Listen on 127.0.0.1 (default: 8010)
--database <path>      Seed the independent Web data root from SQLite / S3DB
--data-dir <path>      Override the independent Local Web data root
--no-open              Do not open the default browser after readiness
--help                 Show this help
```

The script serves `NavPlanner/Resources/Web/` directly. It never creates a tracked UI copy and
does not read the deleted `NavPlanner-web/` project. When `--database` is omitted in a development
checkout, the ignored `database/e_dfd_PMDG_release.s3db` is detected if present; the source file is
copied into the independent Local Web data directory and is not modified in place.

The native server requires Swift 6.1 or newer. macOS/Linux default to pinned Hummingbird 2.22.0;
because that release does not support Windows, Windows compiles a thin direct SwiftNIO 2.101.3
transport instead. Both feed the same transport-neutral request processor and runtime router.
Press Control-C to stop it. `--watch` remains reserved for a later reload phase and currently
fails explicitly instead of changing startup behavior silently.

Security defaults are active in development: the socket binds only to `127.0.0.1`, Host and
Origin are restricted to loopback, unsafe requests require a per-process token, and static file
paths cannot escape the shared Web root.

## Cross-platform release payload

Generate a new, self-contained Web candidate without a navigation database or user data:

```bash
Tools/LocalWeb/package_web_release.sh \
  --output /tmp/SimNav-Web-package \
  --build-macos-native
Tools/LocalWeb/audit_web_release.sh /tmp/SimNav-Web-package --docker-smoke
```

The package contains one canonical `app/NavPlanner/Resources/Web` tree, one shared Swift core, and
the SwiftPM transport/security tests declared by its unchanged `Package.swift`, plus pinned
Docker/Compose and macOS, Windows, and Linux run/stop scripts. Docker publishes only to host
`127.0.0.1`; only the marked container may bind `0.0.0.0` internally. Native macOS/Windows
launchers record a per-port PID and their stop scripts verify the executable path before stopping
it; Docker stop scripts preserve the named data volume.

Windows can run the Swift server natively without starting a Linux server. On a Windows x86_64
machine with the official Swift 6.1+ toolchain and vcpkg, build and smoke the direct-SwiftNIO
`.exe` plus its SQLite/Swift runtime DLLs with:

```powershell
Tools/LocalWeb/build_windows_native.ps1 `
  -OutputDirectory C:\Temp\SimNavLocalWeb-windows-x86_64
```

The pinned Windows GitHub workflow runs the same script. Pass its artifact to packaging with
`--windows-native <directory>`. `run-windows.ps1` always prefers that native executable, so it
does not require an installed Swift toolchain or start Linux, WSL, or Docker when the bundle and
its runtime DLLs are present; Docker Desktop is the fallback. The native smoke checks health,
the exact loopback listener, a real HTTP database import, and active-database persistence after
restarting the `.exe`. Linux uses the same Swift sources to build a native Linux executable inside
the pinned image. `audit_web_release.sh --docker-smoke` runs the packaged Swift tests, the default
Hummingbird container path, and a forced SwiftNIO transport path with Host, Range, import, and
restart-persistence checks. The Linux XCTest binary is enumerated and run one case at a time with
a per-case timeout, avoiding an XCTest cross-test lifecycle hang while retaining every discovered
case and reporting the exact failure.
