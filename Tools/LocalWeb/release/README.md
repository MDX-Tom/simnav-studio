# SimNav Studio Local Web

This is the third formal SimNav Studio platform, alongside iOS/iPadOS and macOS. It serves the
same `Resources/Web` UI and compiles the same Swift planner, data, map, FR24, and runtime-router
sources used by the apps. It does not contain a second frontend or backend implementation.

## Start / 启动

- macOS: double-click `run-macos.command`. The universal native server is preferred; Docker is
  the fallback. Explicit FR24 verification uses an App-owned WebKit window and does not launch a
  third-party browser.
- Windows: right-click `run-windows.ps1` and choose **Run with PowerShell**. A packaged
  SwiftNIO `simnav-local-web.exe` runs directly on Windows with no Linux server. Docker Desktop
  is used only when that native bundle is absent; the managed Chrome/Chromium/Edge process stays
  hidden unless the user explicitly opens the FR24 verification page.
- Linux: run `./run-linux.sh`. Docker builds and runs the native Linux Swift server, while the
  launcher keeps its managed Chrome/Chromium/Edge process off-screen until explicit verification.

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
Web uses a private platform verification session. macOS hosts it in an App-owned WebKit window;
Windows/Linux select Chrome, Chromium, or Edge from the actual environment with an isolated profile
under the Web data root. Startup, schedule, history, and playback use the shared Swift FR24 backend
without browser data pages. Select **Open FR24 verification page** to show the dedicated window;
after the normal FR24 / Cloudflare verification completes, Local Web automatically transfers the
session and closes the page. Windows/Linux Chromium fallback uses a randomized non-zero private
loopback DevTools port, preserving normal headed-browser semantics. The shared Swift `FR24Service` performs route
queries and playback downloads after that session handoff; no official API credential is requested,
normal browser profiles are not read, and session data is stored only in Local Web's private data
root. GPX and FR24 CSV/KML import remain available. Local Web does not automate
CAPTCHA or bypass Cloudflare.

For Windows/Linux Docker launches, Chromium exposes DevTools on host loopback only. Linux forwards it
only through the private Compose gateway; Windows uses an ephemeral authenticated host relay. The
container never receives the user's normal browser profile, and the user-facing steps are
**query → if challenged, open verification page → complete the normal check → automatic sync and
close → query/download/draw/match**.

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
