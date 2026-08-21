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

Local Web FR24 uses the same `FR24Service` as the Apple Apps. Query, history, and playback run through
that shared Swift backend without creating browser data pages. On macOS, the explicit **Open FR24
verification page** action creates an App-owned WebKit window in the Local Web process; it does not
launch Edge, Chrome, Safari, or the user's default browser. Windows/Linux use a thin private
Chrome/Chromium/Edge CDP adapter for the same explicit action, selected from the actual environment.
After the normal FR24 / Cloudflare verification completes, Local Web copies the session into its
private state, probes it through `FR24Service`, and closes the page automatically. Chromium fallback
reserves a randomized non-zero loopback DevTools port, preserving normal headed-browser semantics
while keeping the endpoint host-private. No official API credential is requested and the normal
browser profile is never opened. GPX and FR24
CSV/KML import plus **Match Current Track** continue to use the same local Swift route engine.
Native Windows launches the isolated fallback directly. Linux Docker keeps it on the Linux desktop
and exposes loopback CDP only to a relay bound to the private Compose gateway; the Windows Docker
fallback uses an ephemeral authenticated PowerShell relay. CDP HTTP and WebSocket
are transported by the pinned SwiftNIO dependency, while every session probe, schedule, playback,
cache, and match decision remains in the shared `FR24Service` and `SimNavRuntimeRouter`.

## Cross-platform release payload

Generate a new, self-contained Web candidate with the release-selected navigation database but
without user data:

```bash
Tools/LocalWeb/package_web_release.sh \
  --output /tmp/SimNav-Web-package \
  --build-macos-native \
  --database database/e_dfd_PMDG_release.s3db
Tools/LocalWeb/audit_web_release.sh /tmp/SimNav-Web-package \
  --expected-database database/e_dfd_PMDG_release.s3db \
  --docker-smoke
```

The package contains one canonical `app/NavPlanner/Resources/Web` tree, one shared Swift core, and
the same byte-for-byte `Database/navdata.sqlite` selected for the iOS and macOS release artifacts,
the SwiftPM transport/security tests declared by its unchanged `Package.swift`, plus pinned
Docker/Compose and macOS, Windows, and Linux run/stop scripts. The database argument defaults to
the ignored `database/e_dfd_PMDG_release.s3db`; packaging fails if it is missing or invalid. On the
first launch the shared data store copies that read-only release input into the independent Web
data root. Later user imports remain active and are not overwritten by an upgrade. No user maps,
GPX tracks, session state, cache, tokens, or logs are packaged. Docker publishes only to host
`127.0.0.1`; only the marked container may bind `0.0.0.0` internally. The Linux FR24 relay binds
only the private Compose gateway; the Windows relay requires a random per-run token and strips it
before forwarding to the browser. Native macOS/Windows
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
