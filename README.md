<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="Media/navplanner-hero-en-dark.webp" />
  <source media="(prefers-color-scheme: light)" srcset="Media/navplanner-hero-en.webp" />
  <img src="Media/navplanner-hero-en.webp" alt="NavPlanner on iPhone and iPad, showing the LGAV to EDDM route and STAR selection" width="84%" />
</picture><br />

<p>
  <a href="https://github.com/MDX-Tom/NavPlanner-App/stargazers"><img src="https://img.shields.io/github/stars/MDX-Tom/NavPlanner-App?logo=github&label=Stars" alt="GitHub Stars" /></a>
  <img src="https://img.shields.io/badge/Devices-iPhone%20%7C%20iPad%20%7C%20Mac-475569" alt="iPhone, iPad, and Mac" />
  <img src="https://img.shields.io/badge/Swift-5.0-F05138?logo=swift&logoColor=white" alt="Swift 5.0" />
  <img src="https://img.shields.io/badge/Version-0.1.0-0F766E" alt="Version 0.1.0" />
</p>

<p>
  <a href="README.md"><img src="https://img.shields.io/badge/lang-English-2563EB.svg" alt="English" /></a>
  <a href="README.zh-CN.md"><img src="https://img.shields.io/badge/语言-简体中文-DC2626.svg" alt="简体中文" /></a>
</p>

<h1>NavPlanner</h1>

<p><strong>From route planning to map review—an all-in-one flight-simulation workspace with local computation.</strong></p>
<p>Native on iPhone &amp; iPad · Route planning · Procedure inspection · Track comparison · Offline maps</p>

<p>
  <a href="#overview">Overview</a> ·
  <a href="#highlights">Highlights</a> ·
  <a href="#showcase">Showcase</a> ·
  <a href="#workflows">Workflows</a> ·
  <a href="#architecture">Architecture</a> ·
  <a href="#build-from-source">Build</a>
</p>

</div>

<!-- README_SYNC: Keep README.md and README.zh-CN.md structurally aligned; visual assets must work in both light and dark themes. -->

<a id="overview"></a>

## Overview ✈️

NavPlanner is an iOS planning desk for flight simulation. It brings **route planning**, **airport and procedure inspection**, **FR24 track download, comparison, and matching**, **offline maps**, and **local navigation databases** into one app—connecting an end-to-end workflow from route idea to map review while keeping core features available offline.

A SwiftUI shell surrounds a WKWebView map workspace and an in-app Swift service layer. Imported databases, map packages, caches, preferences, and track history remain inside the app sandbox.

<p align="center">
  <strong>Route idea</strong> → <strong>Automatic planning</strong> → <strong>Procedure selection</strong> → <strong>Flight profile calculation</strong> → <strong>Map replay</strong>
</p>

> [!CAUTION]
> **For flight simulation only.** NavPlanner is not certified aviation software and must not be used for real-world flight planning, navigation, dispatch, operational decisions, or any safety-critical aviation activity.

<a id="highlights"></a>

## Highlights ✨

|  | Capability | What it brings |
|:--:|---|---|
| 🧭 | **Local route planning** | Build and draw a route from departure to arrival, leave Route blank for full auto-planning, or insert `***` between fixes to auto-plan one segment. |
| 🛬 | **Airport & procedure inspection** | Browse runways, frequencies, `SID`, `STAR`, and `APPROACH` paths, including RF / AF arcs, missed approaches, and holding geometry. |
| 🗺️ | **Layered map workspace** | Toggle basemaps, route types, procedures, FR24 tracks, waypoints, navaids, runways, ILS, and airway labels; undo, redo, or clear drawn tracks. |
| 📐 | **Flight calculation desk** | Configure aircraft, weight, fuel, cruise, descent, weather, and QNH; review wind / terrain and ground-speed / vertical-speed profiles plus a SimBrief-style fuel estimate. |
| 📡 | **FR24 track comparison** | Query recent flights or a flightId after syncing an in-app browser session, import GPX, inspect profiles, and match recorded tracks to local route data. |
| 💾 | **Offline map library** | Import or download PMTiles, MBTiles, SQLite tile stores, and legacy Web `tiles/` layouts while managing online cache separately. |
| 🗄️ | **Local navigation databases** | Import `.s3db`, `.sqlite`, `.sqlite3`, or `.db`, switch databases, remove unused copies, and restore the bundled database. |

<a id="showcase"></a>

## Interface Showcase 🖥️

<table align="center" width="80%">
  <tr>
    <td align="center"><strong>Light · iPhone 17 Pro portrait</strong><br /><img alt="NavPlanner light theme on iPhone previewing the runway-filtered EDDM STAR overview" src="Media/workflows/en/day/02-procedure-iphone.webp" height="272" /></td>
    <td align="center"><strong>Light · iPad Pro 13-inch landscape</strong><br /><img alt="NavPlanner light theme on iPad previewing the runway-filtered EDDM STAR overview" src="Media/workflows/en/day/02-procedure-ipad.webp" height="272" /></td>
  </tr>
  <tr>
    <td align="center"><strong>Dark · iPhone 17 Pro portrait</strong><br /><img alt="NavPlanner dark theme on iPhone previewing the runway-filtered EDDM STAR overview" src="Media/workflows/en/night/02-procedure-iphone.webp" height="272" /></td>
    <td align="center"><strong>Dark · iPad Pro 13-inch landscape</strong><br /><img alt="NavPlanner dark theme on iPad previewing the runway-filtered EDDM STAR overview" src="Media/workflows/en/night/02-procedure-ipad.webp" height="272" /></td>
  </tr>
</table>

<p align="center"><sub>Interface showcase: EDDM RW08R STAR procedure preview.</sub></p>

<a id="workflows"></a>

## Core Workflows 🧭

<details open>
<summary><strong>1 · Plan and draw a route</strong></summary>

1. Open the **Plan** tab.
2. Enter departure and arrival airports, for example `KLAX` and `KJFK`.
3. Pick runways or keep automatic selection.
4. Enter a route string, leave it blank for full auto-planning, or use `***` between fixes to auto-plan a segment.
5. Tap **Generate & Draw Route**.

<table align="center" width="92%">
  <tr>
    <th align="center">iPhone</th>
    <th align="center">iPad/macOS</th>
  </tr>
  <tr>
    <td align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="Media/workflows/en/night/01-plan-iphone.webp" /><source media="(prefers-color-scheme: light)" srcset="Media/workflows/en/day/01-plan-iphone.webp" /><img alt="Plan and draw LGAV to EDDM on iPhone" src="Media/workflows/en/day/01-plan-iphone.webp" height="313" /></picture></td>
    <td align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="Media/workflows/en/night/01-plan-ipad.webp" /><source media="(prefers-color-scheme: light)" srcset="Media/workflows/en/day/01-plan-ipad.webp" /><img alt="Plan and draw LGAV to EDDM on iPad" src="Media/workflows/en/day/01-plan-ipad.webp" height="313" /></picture></td>
  </tr>
</table>

</details>

#

<details open>
<summary><strong>2 · Inspect airports and procedures</strong></summary>

1. Build a route, then open the **Airport** tab and switch to the EDDM arrival slot.
2. Select a runway such as `RW08R` and review the filtered procedure lists.
3. Tap the **STAR** heading to preview all matching STAR paths, or tap one procedure to focus its path.
4. Review runway data, communication frequencies, and the visible procedure geometry together.

<table align="center" width="92%">
  <tr>
    <th align="center">iPhone</th>
    <th align="center">iPad/macOS</th>
  </tr>
  <tr>
    <td align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="Media/workflows/en/night/02-procedure-iphone.webp" /><source media="(prefers-color-scheme: light)" srcset="Media/workflows/en/day/02-procedure-iphone.webp" /><img alt="Select EDDM RW08R and preview its STAR overview on iPhone" src="Media/workflows/en/day/02-procedure-iphone.webp" height="313" /></picture></td>
    <td align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="Media/workflows/en/night/02-procedure-ipad.webp" /><source media="(prefers-color-scheme: light)" srcset="Media/workflows/en/day/02-procedure-ipad.webp" /><img alt="Select EDDM RW08R and preview its STAR overview on iPad" src="Media/workflows/en/day/02-procedure-ipad.webp" height="313" /></picture></td>
  </tr>
</table>

</details>

#

<details open>
<summary><strong>3 · Calculate profiles and fuel</strong></summary>

1. Build a route in **Plan** and select any required `SID`, `STAR`, or `APPROACH`.
2. Open **Calc**, select manufacturer and aircraft type, then adjust ZFW, fuel on board, cruise altitude, cruise Mach, descent rate, weather source, weight unit, and QNH unit.
3. Review the SimBrief-style route profile with relative wind, cloud, precipitation, terrain, procedure altitude limits, QNH, zoom, and pan controls.
4. Check the ground-speed / vertical-speed profile and fuel estimate.

The calculation model is local-first and works offline. Online weather is an enhancement and falls back to local estimates when unavailable; Terrarium DEM tiles are sampled when available and degrade to a conservative local terrain estimate when unavailable. Direct weather-source licensing, offline DEM packages, and fuller aircraft-performance libraries remain planned enhancements.

<table align="center" width="92%">
  <tr>
    <th align="center">iPhone</th>
    <th align="center">iPad/macOS</th>
  </tr>
  <tr>
    <td align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="Media/workflows/en/night/03-calculate-iphone.webp" /><source media="(prefers-color-scheme: light)" srcset="Media/workflows/en/day/03-calculate-iphone.webp" /><img alt="Calculate the LGAV to EDDM flight profile on iPhone" src="Media/workflows/en/day/03-calculate-iphone.webp" height="313" /></picture></td>
    <td align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="Media/workflows/en/night/03-calculate-ipad.webp" /><source media="(prefers-color-scheme: light)" srcset="Media/workflows/en/day/03-calculate-ipad.webp" /><img alt="Calculate the LGAV to EDDM flight profile on iPad" src="Media/workflows/en/day/03-calculate-ipad.webp" height="313" /></picture></td>
  </tr>
</table>

</details>

#

<details open>
<summary><strong>4 · FR24 tracks: query, download, replay, and match</strong></summary>

1. Fill departure and arrival airports in Plan, then open **Query**.
2. For the first query, open the verification page in the in-app browser, complete the FR24 / Cloudflare check, and sync the browser session.
3. List up to 10 recent flights for the route, or search a flight number / flightId manually.
4. Download and draw a track, import GPX, inspect altitude / speed profiles, or match the track against the local route engine.

Flights that have not departed are shown as deep-gray scheduled cards. Because FR24 has no actual playback for them yet, NavPlanner clearly labels the limitation and can draw a dashed preview generated by the local auto-planner; the dashed line is not presented as an actual or filed FR24 track.

When a loaded flight reports different actual airports, Query synchronizes them back to Plan before matching. For dense tracks with reliable terminal samples, matching identifies the complete SID / STAR / Approach first, then fits the enroute airway between procedure boundaries.

Downloaded tracks are cached locally as GPX, playback JSON, and metadata. Query can search the cache, draw or match cached tracks, share GPX, favorite important tracks, open the cache folder, and clear non-favorited downloads.

> **Online enhancement.** FR24 is optional. If the network is unavailable, the session expires, or FR24 returns a verification page, local planning, airport lookup, procedures, nav overlays, and offline maps remain available. NavPlanner reuses only the session completed by the user inside the app; it does not bypass Cloudflare or automate CAPTCHA challenges.

<table align="center" width="92%">
  <tr>
    <th align="center">iPhone</th>
    <th align="center">iPad/macOS</th>
  </tr>
  <tr>
    <td align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="Media/workflows/en/night/04-fr24-iphone.webp" /><source media="(prefers-color-scheme: light)" srcset="Media/workflows/en/day/04-fr24-iphone.webp" /><img alt="Draw and inspect an LGAV to EDDM FR24 profile on iPhone" src="Media/workflows/en/day/04-fr24-iphone.webp" height="313" /></picture></td>
    <td align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="Media/workflows/en/night/04-fr24-ipad.webp" /><source media="(prefers-color-scheme: light)" srcset="Media/workflows/en/day/04-fr24-ipad.webp" /><img alt="Draw and inspect an LGAV to EDDM FR24 profile on iPad" src="Media/workflows/en/day/04-fr24-ipad.webp" height="313" /></picture></td>
  </tr>
</table>

</details>

#

<details open>
<summary><strong>5 · Manage offline maps and navigation databases</strong></summary>

**Offline maps**

1. Open **Settings** → **Manage Offline Maps**.
2. Import or download PMTiles, MBTiles, or SQLite tile resources.
3. Select an active resource to make the map prefer local tiles.

Online map cache and offline packages are managed separately. Clearing the online cache does not remove imported maps or navigation databases.

**Navigation databases**

1. In **Settings** → **Navigation Database**, tap **Choose s3db**.
2. Pick a `.s3db`, `.sqlite`, `.sqlite3`, or `.db` file from Files; its format must match the [custom navigation-database compatibility](#nav-db-compatible-format) section below.
3. NavPlanner switches to the imported database and refreshes route, procedure, and nav-overlay caches.

<a id="nav-db-compatible-format"></a>
<details>
<summary><strong>Custom navigation-database compatibility</strong></summary>

It is recommended to use the PMDG aircraft navigation database
`e_dfd_PMDG.s3db`, or customize a copy of it.

The extension is only a file-picker filter: the imported file must be a valid
**SQLite 3** database using the PMDG-style navigation schema queried by
NavPlanner. The app copies an import into its sandbox and opens that copy
read-only. It does not convert CSV, JSON, ARINC 424 source text, encrypted
databases, or arbitrary SQLite schemas.

Full route-planning, airport, procedure, and overlay compatibility requires
these tables and their existing PMDG field names:

| Data area | Required tables and principal fields |
|---|---|
| Cycle metadata | `tbl_header` (`current_airac`, `revision`; one header row) |
| Airports | `tbl_airports` (`airport_identifier`, `iata_ata_designator`, `airport_name`, `airport_ref_latitude`, `airport_ref_longitude`) |
| Runways & communications | `tbl_runways` (airport/runway identifiers, threshold coordinates, bearing and dimensions), `tbl_airport_communication` (airport identifier, type, frequency and callsign) |
| Fixes & navaids | `tbl_enroute_waypoints`, `tbl_terminal_waypoints`, `tbl_vhfnavaids`, `tbl_enroute_ndbnavaids`, `tbl_terminal_ndbnavaids` (identifier/name, latitude/longitude and the table's type/frequency fields) |
| Airways | `tbl_enroute_airways` (`route_identifier`, `seqno`, waypoint identifier/coordinates, direction, route type, altitude/course/distance fields) |
| Procedures | `tbl_sids`, `tbl_stars`, `tbl_iaps` (airport/procedure/transition identifiers, `route_type`, `seqno`, waypoint coordinates, path termination, course/arc, altitude/speed and recommended/center-fix fields) |
| ILS | `tbl_localizers_glideslopes` (airport/runway/localizer identifiers, localizer coordinates, bearing and frequency) |

Identifiers should use their normal uppercase ICAO/PMDG values; latitude and
longitude are WGS 84 decimal degrees; procedure and airway sequence values must
sort in flight-path order. Bearings/courses, runway dimensions, altitude fields,
frequencies, route types, and path terminators must retain the units and
semantics of the PMDG schema (the app interprets runway length as feet).
Additional tables and indexes are allowed, but renaming the queried tables or
columns is not.

Before importing, a basic integrity and schema check can be run with:

```bash
sqlite3 -readonly custom.s3db "PRAGMA quick_check;"
sqlite3 -readonly custom.s3db \
  "SELECT current_airac, revision FROM tbl_header LIMIT 1;"
sqlite3 -readonly custom.s3db \
  "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;"
```

`PRAGMA quick_check` should return `ok`. A database that merely opens but lacks
the required tables or columns may import successfully while affected features
return no data. You are responsible for the accuracy, legality, and import or
redistribution rights of every custom database.

</details>

<table align="center" width="92%">
  <tr>
    <th align="center">iPhone</th>
    <th align="center">iPad/macOS</th>
  </tr>
  <tr>
    <td align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="Media/workflows/en/night/05-settings-iphone.webp" /><source media="(prefers-color-scheme: light)" srcset="Media/workflows/en/day/05-settings-iphone.webp" /><img alt="Manage offline maps and local settings on iPhone" src="Media/workflows/en/day/05-settings-iphone.webp" height="313" /></picture></td>
    <td align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="Media/workflows/en/night/05-settings-ipad.webp" /><source media="(prefers-color-scheme: light)" srcset="Media/workflows/en/day/05-settings-ipad.webp" /><img alt="Manage offline maps and the navigation database on iPad" src="Media/workflows/en/day/05-settings-ipad.webp" height="313" /></picture></td>
  </tr>
</table>

</details>

<a id="architecture"></a>

## Architecture 🏗️

The architecture is organized around the user-facing core workflow rather than starting from frameworks. Each numbered stage expands as **feature entry → local API → implementation principle → returned payload**, while the shared runtime and local data plane stay visible across the whole path.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="Media/architecture/project-architecture-en-dark.webp" />
  <source media="(prefers-color-scheme: light)" srcset="Media/architecture/project-architecture-en-light.webp" />
  <img src="Media/architecture/project-architecture-en-light.webp" alt="NavPlanner architecture: workflow-first system design" />
</picture>

The numbered workflow makes the dependency direction explicit: route planning produces the payload consumed by Airport, Calc, and Query; Procedure selection constrains both profile calculation and track matching; Settings feeds the local database and map stores that every offline path depends on. The arrows also expose the implementation principles:

| Principle | Implementation boundary | Result |
|---|---|---|
| **Local-first core** | `PlannerService` + `LocalDataStore` + `MapStore` | Route resolution, procedures, nav-overlay, local maps, and database inspection continue without network access. |
| **Procedure-first matching** | actual-airport sync → terminal procedure fit → airway A* → smoothing | Recorded tracks preserve SID / STAR / APPROACH context before enroute matching. |
| **Online as enhancement** | FR24 session, Open-Meteo, and Terrarium DEM are dashed optional paths | Network/session failures fall back to local estimates and do not replace the core workflow. |
| **Typed payload boundaries** | `navplanner://` API and JS bridge | Each stage returns a payload that can be rendered by the map or the active workspace panel without sharing storage internals. |
| **Separated cache domains** | SQLite navigation DB, offline map packages, online tile cache, and FR24 cache | Import, refresh, clear, and rollback operations stay scoped to the resource they own. |

<a id="build-from-source"></a>

## Build From Source 🛠️

### Requirements

- macOS with Xcode
- iOS 17.0 or later deployment target
- iPhone / iPad Simulator, macOS, or a physical device
- Optional local navigation database for private builds

### Quick start

```bash
git clone https://github.com/MDX-Tom/NavPlanner-App.git
cd NavPlanner-App
Tools/Signing/setup_local_signing.sh
open NavPlanner.xcodeproj
```

The signing helper reads the Team ID from a valid Apple Development certificate
and writes it only to the Git-ignored
`Config/CodeSigning.local.xcconfig`. If your account cannot provision the public
Bundle Identifier, pass a private override such as
`--bundle-id com.example.NavPlanner`. Simulator builds do not require signing.
For a physical device, first add your Apple Account and create an Apple
Development certificate in Xcode if the helper reports that no identity exists.
If Xcode later reports that no profile is available or that a profile expired,
open **Xcode → Settings → Accounts**, refresh the Apple Account and certificates,
then rerun the helper. Account credentials remain in Xcode and Keychain and must
never be copied into this repository.

In Xcode, select the **NavPlanner** scheme, choose an iPhone, iPad, or Mac
Catalyst destination, and run the app. Xcode automatically reads the ignored
local configuration; it does not write the Team ID into the tracked project.

For Debug or private builds, place a local database at
`NavPlanner/Resources/Database/navdata.sqlite`, or import one from Settings after
launch. Public release builds do not use that development copy:
`Tools/Release/build_public_release.sh` requires the latest local
`database/e_dfd_PMDG_release.s3db`, validates it, and temporarily bundles it as
`Database/navdata.sqlite` in both the IPA and DMG. Both database locations are
Git-ignored.

<details>
<summary><strong>Command-line build</strong></summary>

```bash
xcodebuild -project NavPlanner.xcodeproj \
  -scheme NavPlanner \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/NavPlannerDerived \
  build
```

If `xcode-select` points to Command Line Tools, set the full Xcode developer directory explicitly:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project NavPlanner.xcodeproj \
  -scheme NavPlanner \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/NavPlannerDerived \
  build
```

</details>

### Install the IPA and DMG from Releases

<details>
<summary><strong>Why this matters</strong></summary>

Public GitHub IPA assets must be unsigned sideload packages. They must not
contain a maintainer certificate, Team ID, provisioning profile, account email,
private key, App Store Connect key, xcarchive, or raw build log.

Local Apple Development settings belong only in the Git-ignored
`Config/CodeSigning.local.xcconfig`. The tracked
`Config/CodeSigning.xcconfig` optionally includes that file, so Xcode GUI builds
work locally while a fresh clone and public unsigned builds contain no private
identity. A Mac artifact without private CI credentials is ad-hoc signed and
not notarized; Developer ID/App Store signing, if ever used, must import
credentials only from protected CI secrets. See
[public release packaging](Tools/Release/README.md).

</details>

**Installing the iPhone app requires AltStore, SideStore, Sideloadly, or another
trusted signing workflow that re-signs it with your own account.**

<details>
<summary><strong>Install on iPhone, iPad, and Mac</strong></summary>

#### iPhone and iPad

The GitHub IPA is unsigned, contains no maintainer certificate or provisioning
profile, and cannot be installed directly.

1. Download the `-unsigned.ipa` and `SHA256SUMS.txt`, then verify the checksum.
2. Import the IPA into AltStore, SideStore, Sideloadly, or another signing tool
   you trust.
3. Let that tool re-sign the IPA with your own Apple Account and install it.
4. Follow the tool and device prompts to trust the resulting local signature;
   enable Developer Mode only when iOS/iPadOS requests it.

Alternatively, you can install directly from local Xcode by running
`Tools/Signing/setup_local_signing.sh`, connecting the device, selecting it as
the NavPlanner destination, and pressing Run. The generated signing file remains
only on that Mac and is ignored by Git.

#### Mac

1. Download the `-catalyst-adhoc-not-notarized.dmg` and verify its SHA-256.
2. Open the DMG and drag `NavPlanner.app` to Applications.
3. On first launch, Control-click the app and choose **Open**. If macOS still
   blocks it, use **System Settings → Privacy & Security → Open Anyway** only
   after verifying the checksum and download source.

The current Mac build is a universal arm64/x86_64 Mac Catalyst app. It is
ad-hoc signed and not notarized, so it does not have Developer ID/Gatekeeper
public-distribution trust; it is not a native AppKit app or a Designed-for-iPad
wrapper.

</details>

<a id="validation"></a>

## Validation & Release Checks ✅

<details>
<summary><strong>Useful local checks</strong></summary>

```bash
node --check NavPlanner/Resources/Web/app.js
node --check NavPlanner/Resources/Web/vendor/maplibre-gl/maplibre-gl.js
plutil -lint NavPlanner.xcodeproj/project.pbxproj NavPlanner/Support/PrivacyInfo.xcprivacy
python3 Tools/Parity/run_all_parity.py
```

`Tools/Parity` compares the Swift local service layer against the read-only Web reference implementation after route-planning, track-matching, or procedure-geometry changes.

</details>

<details>
<summary><strong>Release checklist</strong></summary>

- Review `PrivacyInfo.xcprivacy` against actual network, file, cache, and optional FR24 behavior.
- Replace `database/e_dfd_PMDG_release.s3db` with the latest release database; verify its AIRAC, `PRAGMA quick_check`, bundled SHA-256 parity, and compatibility in both the IPA and DMG.
- Confirm licensing and distribution rights for the bundled example database, imported navigation databases, offline map packages, and basemap sources.
- Update version, build number, display name, signing, app icon, and alternate-icon metadata.
- Test iPhone compact width, iPhone landscape, iPad portrait, and iPad landscape.
- Verify airplane-mode launch, airport search, airport detail, route planning, procedure drawing, nav-overlay rendering, and offline maps.
- Verify FR24 missing-session, Cloudflare-verification, flightId, GPX import, profile scrubbing, failed-download, drawing, matching, sharing, and cache-management paths.
- Filter Xcode logs by the `NavPlanner` process; beta simulators may print unrelated system-service errors.

</details>

<a id="project-layout"></a>

## Project Layout 🗂️

```text
NavPlanner.xcodeproj/          Xcode project
NavPlanner/
  App/                         SwiftUI app entry and shell
  Core/                        Local database, planner, map store, WebBridge
  Features/                    SwiftUI feature containers
  Resources/Web/               WKWebView map workspace resources
  Support/                     Asset catalog and privacy manifest
Tools/                         Icon generation and parity tools
Media/                         README screenshots and visual assets
```

<a id="data-notice"></a>

## Data & Safety Notice ⚠️

**NavPlanner is a simulator-planning, inspection, and personal-learning aid only. For real-world aviation, always rely on official aeronautical publications, ATC instructions, certified avionics, and current operational procedures.**

NavPlanner may use third-party or user-supplied materials, including basemaps, airport and procedure data, AIRAC / navigation databases, PMTiles / MBTiles / SQLite packages, and FR24 flight data. These materials may be subject to copyright, database rights, trademarks, platform terms, or redistribution restrictions.

The public GitHub source
repository does **not** include a navigation database: the root `database/`
directory and the development bundle resource are Git-ignored. The IPA and
DMG published under Releases include an example database and stored inside the app, so the app has usable sample data on first launch.
No IPA or DMG containing this sample may be published by the maintainers.

This app does not guarantee the accuracy, completeness, availability, or legal status of third-party data. You are responsible for confirming your right to use, import, cache, and distribute each data source.
