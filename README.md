<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="Media/navplanner-hero-dark.webp" />
  <source media="(prefers-color-scheme: light)" srcset="Media/navplanner-hero-light.webp" />
  <img src="Media/navplanner-hero-light.webp" alt="NavPlanner — a local-first sim-flight planning desk" width="84%" />
</picture><br />

<p>
  <a href="https://github.com/MDX-Tom/NavPlanner-App/stargazers"><img src="https://img.shields.io/github/stars/MDX-Tom/NavPlanner-App?logo=github&label=Stars" alt="GitHub Stars" /></a>
  <img src="https://img.shields.io/badge/iOS-17.0%2B-0A84FF?logo=apple&logoColor=white" alt="iOS 17.0+" />
  <img src="https://img.shields.io/badge/Swift-5.0-F05138?logo=swift&logoColor=white" alt="Swift 5.0" />
  <img src="https://img.shields.io/badge/UI-SwiftUI-0D96F6?logo=swift&logoColor=white" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/Devices-iPhone%20%7C%20iPad-475569" alt="iPhone and iPad" />
  <img src="https://img.shields.io/badge/Version-0.1.0-0F766E" alt="Version 0.1.0" />
  <img src="https://img.shields.io/badge/Mode-Local--first-7C3AED" alt="Local-first" />
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

<p align="center">
  <img alt="NavPlanner iPad map workspace" src="Media/ipad-us.webp" width="60%" />
  &nbsp;&nbsp;
  <img alt="NavPlanner iPhone route planning workspace" src="Media/iphone-us.webp" width="28%" />
</p>
<p align="center"><sub>Adaptive iPad workspace and compact iPhone planning flow.</sub></p>

<a id="workflows"></a>

## Core Workflows 🧭

<details open>
<summary><strong>1 · Plan and draw a route</strong></summary>

1. Open the **Plan** tab.
2. Enter departure and arrival airports, for example `KLAX` and `KJFK`.
3. Pick runways or keep automatic selection.
4. Enter a route string, leave it blank for full auto-planning, or use `***` between fixes to auto-plan a segment.
5. Tap **Generate & Draw Route**.

</details>

<details>
<summary><strong>2 · Inspect airports and procedures</strong></summary>

1. Enter a manual airport in Plan, or tap an airport on the map.
2. Open the **Airport** tab and switch between departure, arrival, and manual slots.
3. Review runways, communication frequencies, and procedure lists.
4. Tap a procedure to preview its path on the map.

</details>

<details>
<summary><strong>3 · Calculate profiles and fuel</strong></summary>

1. Build a route in **Plan** and select any required `SID`, `STAR`, or `APPROACH`.
2. Open **Calc**, select manufacturer and aircraft type, then adjust ZFW, fuel on board, cruise altitude, cruise Mach, descent rate, weather source, weight unit, and QNH unit.
3. Review the SimBrief-style route profile with relative wind, cloud, precipitation, terrain, procedure altitude limits, QNH, zoom, and pan controls.
4. Check the ground-speed / vertical-speed profile and fuel estimate.

The calculation model is local-first and works offline. Online weather is an enhancement and falls back to local estimates when unavailable; Terrarium DEM tiles are sampled when available and degrade to a conservative local terrain estimate when unavailable. Direct weather-source licensing, offline DEM packages, and fuller aircraft-performance libraries remain planned enhancements.

</details>

<details>
<summary><strong>4 · FR24 tracks: query, download, replay, and match</strong></summary>

1. Fill departure and arrival airports in Plan, then open **Query**.
2. For the first query, open the verification page in the in-app browser, complete the FR24 / Cloudflare check, and sync the browser session.
3. List up to 10 recent flights for the route, or search a flight number / flightId manually.
4. Download and draw a track, import GPX, inspect altitude / speed profiles, or match the track against the local route engine.

When a loaded flight reports different actual airports, Query synchronizes them back to Plan before matching. For dense tracks with reliable terminal samples, matching identifies the complete SID / STAR / Approach first, then fits the enroute airway between procedure boundaries.

Downloaded tracks are cached locally as GPX, playback JSON, and metadata. Query can search the cache, draw or match cached tracks, share GPX, favorite important tracks, open the cache folder, and clear non-favorited downloads.

> **Online enhancement.** FR24 is optional. If the network is unavailable, the session expires, or FR24 returns a verification page, local planning, airport lookup, procedures, nav overlays, and offline maps remain available. NavPlanner reuses only the session completed by the user inside the app; it does not bypass Cloudflare or automate CAPTCHA challenges.

</details>

<details>
<summary><strong>5 · Manage offline maps and navigation databases</strong></summary>

**Offline maps**

1. Open **Settings** → **Manage Offline Maps**.
2. Import or download PMTiles, MBTiles, or SQLite tile resources.
3. Select an active resource to make the map prefer local tiles.

Online map cache and offline packages are managed separately. Clearing the online cache does not remove imported maps or navigation databases.

**Navigation databases**

1. In **Settings** → **Navigation Database**, tap **Choose s3db**.
2. Pick a `.s3db`, `.sqlite`, `.sqlite3`, or `.db` file from Files.
3. NavPlanner switches to the imported database and refreshes route, procedure, and nav-overlay caches.

</details>

<a id="architecture"></a>

## Architecture 🏗️

The architecture is organized around the user-facing core workflow rather than starting from frameworks. Each numbered stage expands as **feature entry → local API → implementation principle → returned payload**, while the shared runtime and local data plane stay visible across the whole path.

```mermaid
flowchart TB
  START(["Core workflow<br/>plan → inspect → calculate → compare"])

  subgraph RUNTIME["Shared runtime and data contract"]
    APP["SwiftUI shell<br/>lifecycle · theme · device layout"]
    WEB["WKWebView workspace<br/>Plan · Airport · Calc · Query · Settings"]
    BRIDGE["navplanner:// scheme handler + JS bridge<br/>typed local API · native callbacks"]
    MAP["Map kernel<br/>Leaflet / MapLibre · overlays · resize-safe rendering"]
    APP --> WEB
    WEB --> BRIDGE
    WEB --> MAP
  end

  subgraph PLAN["1 · Plan → resolve and draw route"]
    PLAN_INPUT["Plan fields<br/>departure · arrival · runways · route / ***"]
    PLAN_API["/api/route/resolve"]
    RESOLVE["PlannerService<br/>airport aliases · identifier validation"]
    ROUTE_ENGINE["Route engine<br/>airway graph · route-between · A* · DCT / *** fallback"]
    ROUTE_PAYLOAD["Route payload<br/>legs · route_display · selected procedures/runways"]
    PLAN_INPUT --> PLAN_API --> RESOLVE --> ROUTE_ENGINE --> ROUTE_PAYLOAD
  end

  subgraph AIRPORT["2 · Airport → inspect procedures"]
    AIRPORT_INPUT["Airport tab / map popup<br/>departure · arrival · manual slot"]
    AIRPORT_API["/api/airport · /api/procedure · /api/procedure-preview · /api/nav-overlay"]
    DB_LOOKUP["PlannerService + SQLite<br/>runway · frequency · procedure lookup"]
    GEOMETRY["Procedure geometry<br/>RF/AF arcs · missed approach · holds · runway filters"]
    PROC_PAYLOAD["Procedure payload<br/>summary · path · altitude/speed limits"]
    AIRPORT_INPUT --> AIRPORT_API --> DB_LOOKUP --> GEOMETRY --> PROC_PAYLOAD
  end

  subgraph CALC["3 · Calculate profiles and fuel"]
    CALC_INPUT["Calc tab<br/>aircraft · weight/fuel · cruise/descent · weather/QNH"]
    LOCAL_MODEL["Local profile model<br/>wind · terrain · performance · fuel"]
    WEATHER["/api/weather/open-meteo<br/>optional pressure-level weather"]
    TERRAIN["/api/terrain/terrarium<br/>optional DEM sampling"]
    PROFILE["Profile payload<br/>FL/hPa · terrain · precipitation · GS/VS · fuel"]
    CALC_INPUT --> LOCAL_MODEL --> PROFILE
    WEATHER -. "enhance / fallback" .-> LOCAL_MODEL
    TERRAIN -. "enhance / fallback" .-> LOCAL_MODEL
  end

  subgraph FR24["4 · Query → replay and match tracks"]
    QUERY_INPUT["Query tab<br/>route · flight / flightId · cached GPX"]
    ACCESS["In-app WKWebView session<br/>optional online path · user-synced"]
    FR24_API["/api/fr24/search · history · download"]
    TRACK_CACHE["FR24 cache<br/>GPX · playback JSON · metadata"]
    MATCH_API["/api/route/track-match"]
    MATCH_ENGINE["Procedure-first matcher<br/>actual-airport sync → SID/STAR/APPROACH → airway A* → smoothing"]
    TRACK_PAYLOAD["Track payload<br/>map line · altitude/speed profile · matched route"]
    QUERY_INPUT --> ACCESS
    ACCESS -. "optional online enhancement" .-> FR24_API
    FR24_API --> TRACK_CACHE
    QUERY_INPUT --> MATCH_API
    TRACK_CACHE --> MATCH_API
    MATCH_API --> MATCH_ENGINE --> TRACK_PAYLOAD
  end

  subgraph DATA["5 · Settings → persist and refresh local data"]
    DATA_INPUT["Settings<br/>import · select · delete · restore · download"]
    DB_STORE["LocalDataStore<br/>Application Support · SQLite · serial reads"]
    MAP_STORE["MapStore / OnlineTileCache<br/>PMTiles · MBTiles · SQLite · cache"]
    STATUS["Status payloads<br/>active database · resource metadata · progress"]
    DATA_INPUT --> DB_STORE --> STATUS
    DATA_INPUT --> MAP_STORE --> STATUS
  end

  START --> PLAN_INPUT
  BRIDGE --> PLAN_INPUT
  BRIDGE --> AIRPORT_INPUT
  BRIDGE --> CALC_INPUT
  BRIDGE --> QUERY_INPUT
  BRIDGE --> DATA_INPUT
  ROUTE_PAYLOAD --> AIRPORT_INPUT
  ROUTE_PAYLOAD --> CALC_INPUT
  ROUTE_PAYLOAD --> QUERY_INPUT
  ROUTE_PAYLOAD --> MATCH_API
  PROC_PAYLOAD --> CALC_INPUT
  PROC_PAYLOAD --> MATCH_ENGINE
  DB_STORE --> RESOLVE
  DB_STORE --> DB_LOOKUP
  MAP_STORE --> MAP
  MAP_STORE --> TERRAIN
  ROUTE_PAYLOAD --> MAP
  PROC_PAYLOAD --> MAP
  TRACK_PAYLOAD --> MAP
  PROFILE --> WEB
  STATUS --> WEB

  classDef runtime fill:#0f172a,color:#ffffff,stroke:#0f172a;
  classDef workflow fill:#0f766e,color:#ffffff,stroke:#0f766e,stroke-width:2px;
  classDef api fill:#e0f2fe,color:#0c4a6e,stroke:#0284c7;
  classDef principle fill:#fef3c7,color:#713f12,stroke:#d97706;
  classDef data fill:#ecfdf5,color:#065f46,stroke:#059669;
  classDef optional fill:#f5f3ff,color:#5b21b6,stroke:#7c3aed,stroke-dasharray:5 5;
  class APP,WEB,BRIDGE,MAP runtime;
  class START,PLAN_INPUT,AIRPORT_INPUT,CALC_INPUT,QUERY_INPUT,DATA_INPUT workflow;
  class PLAN_API,AIRPORT_API,WEATHER,TERRAIN,FR24_API,MATCH_API api;
  class RESOLVE,ROUTE_ENGINE,DB_LOOKUP,GEOMETRY,LOCAL_MODEL,MATCH_ENGINE principle;
  class ROUTE_PAYLOAD,PROC_PAYLOAD,PROFILE,TRACK_PAYLOAD,DB_STORE,MAP_STORE,TRACK_CACHE,STATUS data;
  class WEATHER,TERRAIN,ACCESS,FR24_API optional;
```

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
- iPhone / iPad Simulator or a physical device
- Optional local navigation database for private builds

### Quick start

```bash
git clone https://github.com/MDX-Tom/NavPlanner-App.git
cd NavPlanner-App
open NavPlanner.xcodeproj
```

In Xcode, select the **NavPlanner** scheme, choose an iPhone or iPad destination, configure the signing team and Bundle Identifier for your account, and run the app.

For private builds, place a local database at `NavPlanner/Resources/Database/navdata.sqlite`, or import one from Settings after launch. Public distributions should not include navigation data without confirmed redistribution rights.

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
- Confirm licensing and distribution rights for navigation databases, offline map packages, and basemap sources.
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

NavPlanner is a simulator-planning, inspection, and personal-learning aid only. For real-world aviation, always rely on official aeronautical publications, ATC instructions, certified avionics, and current operational procedures.

NavPlanner may use third-party or user-supplied materials, including basemaps, airport and procedure data, AIRAC / navigation databases, PMTiles / MBTiles / SQLite packages, and FR24 flight data. These materials may be subject to copyright, database rights, trademarks, platform terms, or redistribution restrictions.

This app does not guarantee the accuracy, completeness, availability, or legal status of third-party data. You are responsible for confirming your right to use, import, cache, and distribute each data source.
