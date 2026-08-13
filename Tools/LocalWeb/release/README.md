# SimNav Studio Local Web

This is the third formal SimNav Studio platform, alongside iOS/iPadOS and macOS. It serves the
same `Resources/Web` UI and compiles the same Swift planner, data, map, FR24, and runtime-router
sources used by the apps. It does not contain a second frontend or backend implementation.

## Start / 启动

- macOS: double-click `run-macos.command`. The universal native server is preferred; Docker is
  the fallback.
- Windows: right-click `run-windows.ps1` and choose **Run with PowerShell**. A packaged
  SwiftNIO `simnav-local-web.exe` runs directly on Windows with no Linux server. Docker Desktop
  is used only when that native bundle is absent; the launcher keeps Edge/Chrome on Windows so
  the same visible FR24 verification flow remains available to the container.
- Linux: run `./run-linux.sh`. Docker builds and runs the native Linux Swift server, while the
  launcher keeps the dedicated visible Chrome/Edge/Chromium profile on the Linux desktop.

Open <http://127.0.0.1:8010>. Set `SIMNAV_WEB_PORT` before launching to choose another port.
Container launchers publish only to `127.0.0.1`; the service is not exposed to the LAN or Internet.

macOS 用户双击 `run-macos.command`；Windows 用户用 PowerShell 运行 `run-windows.ps1`；
Linux 用户运行 `./run-linux.sh`。Windows 包含原生 bundle 时会直接运行 Swift `.exe`，
不会启动 Linux/WSL；仅在原生 bundle 缺失时才回退到 Docker Desktop。默认地址为
<http://127.0.0.1:8010>，不会监听局域网或公网。

The Web data root is independent from the apps. This release includes the same permitted example
`Database/navdata.sqlite` selected for its iOS/iPadOS and macOS artifacts. On first launch the
server copies that read-only release database into the Local Web data root and activates it, so
airport search and planning work immediately. A database later imported or selected in the browser
remains active across native-process or container restarts; **Restore bundled database** returns to
the release copy. No user map, track, cookie, FR24 session, cache, log, or secret is bundled. Local
Web opens Chrome, Edge, or Chromium with an isolated profile under its data root. Complete any
normal FR24 / Cloudflare verification in that dedicated window, then select **Sync Browser Session**
in Query. The FR24 homepage remains the only visible verification target; schedule/playback targets
stay in the background and close if challenged. The launchers use a randomized non-zero private
loopback DevTools port, preserving normal headed-browser semantics (`navigator.webdriver=false`)
instead of Chromium's port-zero automation mode. The shared Swift `FR24Service` performs route
queries and playback downloads through the same profile; no official API credential is requested,
normal browser profiles are not read, and
cookies are not exported. GPX and FR24 CSV/KML import remain available. Local Web does not automate
CAPTCHA or bypass Cloudflare.

For Docker launches, Chromium continues to expose DevTools on host loopback only. Linux forwards it
only through the private Compose gateway; Windows uses an ephemeral authenticated host relay. The
container never receives the user's normal browser profile or a cookie export, and the user-facing
steps remain **Open verification page → complete any normal check → Sync Browser Session → query →
download/draw/match**.

Use the matching `stop-*` script for either a recorded native process or the Docker fallback.
Closing a native-server terminal or pressing Control-C also stops that native process. Stop scripts
preserve all Local Web data and the Docker volume; to delete user data, remove the
`simnav-studio-web-data` volume explicitly and only after backing it up.
To upgrade, replace the release directory with a newer verified package and run the matching
launcher again. Docker rebuilds the new pinned source while reusing the same named data volume;
native launchers use the newer bundled binary. Never copy the old `app/` source into a new package.

`SHA256SUMS.txt` covers every shipped file except itself. `web-manifest.json` records the source
revision, platform HTTP transports, and which optional native bundles were included. The source
package also includes the
transport/security regression tests declared by `Package.swift`, so SwiftPM remains valid on every
supported build host.
