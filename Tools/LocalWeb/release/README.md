# SimNav Studio Local Web

This is the third formal SimNav Studio platform, alongside iOS/iPadOS and macOS. It serves the
same `Resources/Web` UI and compiles the same Swift planner, data, map, FR24, and runtime-router
sources used by the apps. It does not contain a second frontend or backend implementation.

## Start / 启动

- macOS: double-click `run-macos.command`. The universal native server is preferred; Docker is
  the fallback.
- Windows: right-click `run-windows.ps1` and choose **Run with PowerShell**. A packaged
  SwiftNIO `simnav-local-web.exe` runs directly on Windows with no Linux server. Docker Desktop
  is used only when that native bundle is absent.
- Linux: run `./run-linux.sh`. Docker builds and runs the native Linux Swift server.

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
the release copy. No user map, GPX track, cookie, FR24 session, cache, log, or token is bundled.
FR24 browser-session sync is Apple WebKit-only; ordinary browsers show a compliant
external-browser/import fallback and do not bypass CAPTCHA or Cloudflare.

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
