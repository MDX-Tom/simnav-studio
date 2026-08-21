import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import SimNavCore

final class PackageBoundaryTests: XCTestCase {
    func testSharedCoreCompilesWithoutWebKit() {
        XCTAssertNotNil(PlannerService.self)
        XCTAssertNotNil(LocalDataStore.self)
        XCTAssertNotNil(MapStore.self)
    }

    func testSharedHTMLPreservesAppleFileBootstrapAndLocalWebRoot() throws {
        var workspaceRoot = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 {
            workspaceRoot.deleteLastPathComponent()
        }
        let html = try String(
            contentsOf: workspaceRoot.appendingPathComponent("NavPlanner/Resources/Web/map.html"),
            encoding: .utf8
        )

        // Apple loads map.html from its bundle with file://, then every CSS/JS
        // request must return to the existing navplanner://app resource bridge.
        // Local Web keeps root-relative HTTP requests from the exact same HTML.
        XCTAssertTrue(html.contains(#"window.location.protocol === "navplanner:""#))
        XCTAssertTrue(html.contains(#"window.location.protocol === "file:""#))
        XCTAssertTrue(html.contains(#"usesAppleResourceBridge ? "navplanner://app/" : "/""#))
        XCTAssertTrue(html.contains(#"href="/styles.css""#))
        XCTAssertTrue(html.contains(#"src="/runtime.js""#))
        XCTAssertTrue(html.contains(#"src="/app.js""#))
    }

    func testSharedAppearanceDefaultsKeepAppleAndWebOnOneSource() throws {
        var workspaceRoot = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 {
            workspaceRoot.deleteLastPathComponent()
        }
        let webRoot = workspaceRoot.appendingPathComponent("NavPlanner/Resources/Web")
        let html = try String(contentsOf: webRoot.appendingPathComponent("map.html"), encoding: .utf8)
        let app = try String(contentsOf: webRoot.appendingPathComponent("app.js"), encoding: .utf8)
        let runtime = try String(contentsOf: webRoot.appendingPathComponent("runtime.js"), encoding: .utf8)
        let zoom = try String(contentsOf: webRoot.appendingPathComponent("ui-zoom.js"), encoding: .utf8)
        let styles = try String(contentsOf: webRoot.appendingPathComponent("styles.css"), encoding: .utf8)
        let calculate = try String(contentsOf: webRoot.appendingPathComponent("pages/calculate.js"), encoding: .utf8)

        XCTAssertTrue(html.contains(#"href="/app-icons/style2-day-medium.png""#))
        XCTAssertTrue(html.contains(#"id="darkMapToggle" type="checkbox""#))
        XCTAssertFalse(html.contains(#"id="darkMapToggle" type="checkbox" checked"#))
        XCTAssertTrue(app.contains(#"darkMapEnabled: savedDarkMapEnabled === "true""#))
        XCTAssertTrue(app.contains(#"providerKey: "arcgis-dark""#))
        XCTAssertTrue(app.contains(#"? migrated : "style2-day-medium""#))
        XCTAssertTrue(runtime.contains(#"iconChoice || "style2-day-medium""#))

        // The Local Web source package intentionally excludes the UIKit shell,
        // Xcode project, and asset catalog. Validate those Apple-only defaults
        // when this test runs from a complete repository checkout; release audit
        // separately checks the compiled IPA and Catalyst asset catalogs.
        let appEnvironmentURL = workspaceRoot.appendingPathComponent("NavPlanner/App/AppEnvironment.swift")
        if FileManager.default.fileExists(atPath: appEnvironmentURL.path) {
            let appEnvironment = try String(contentsOf: appEnvironmentURL, encoding: .utf8)
            let primaryIcon = try String(
                contentsOf: workspaceRoot.appendingPathComponent(
                    "NavPlanner/Support/Assets.xcassets/AppIcon.appiconset/Contents.json"
                ),
                encoding: .utf8
            )
            let style3DefaultIcon = workspaceRoot.appendingPathComponent(
                "NavPlanner/Support/Assets.xcassets/AppIconStyle3DayMedium.appiconset/Contents.json"
            )
            let project = try String(
                contentsOf: workspaceRoot.appendingPathComponent("NavPlanner.xcodeproj/project.pbxproj"),
                encoding: .utf8
            )

            XCTAssertTrue(appEnvironment.contains(#"else { return "style2-day-medium" }"#))
            XCTAssertTrue(appEnvironment.contains(#""style2-day-medium": (nil, "风格2 · 日间默认")"#))
            XCTAssertTrue(appEnvironment.contains(#""style3-day-medium": ("AppIconStyle3DayMedium""#))
            XCTAssertTrue(primaryIcon.contains(#"style2-day-medium-ios-marketing-1024.png"#))
            XCTAssertTrue(FileManager.default.fileExists(atPath: style3DefaultIcon.path))
            XCTAssertTrue(project.contains("AppIconStyle3DayMedium"))
            XCTAssertFalse(project.contains("AppIconStyle2DayMedium"))
        }

        XCTAssertTrue(zoom.contains(#"window.location.protocol === "http:""#))
        XCTAssertTrue(zoom.contains(#"window.location.protocol === "https:""#))
        XCTAssertTrue(zoom.contains(#"root.dataset.runtime = "web""#))
        XCTAssertTrue(zoom.contains("return 0.828;"))
        XCTAssertTrue(zoom.contains(#"root.dataset.platform === "mac" ? 0.9 : 0.8"#))
        XCTAssertTrue(styles.contains(#"html[data-runtime="web"] .shell"#))
        XCTAssertTrue(styles.contains("--detail-panel-width: 385px;"))
        XCTAssertTrue(calculate.contains(#"const width = control.clientWidth || control.getBoundingClientRect?.().width || 0;"#))

        XCTAssertFalse(styles.contains(#"data-theme="night"][data-map-source="online"] .terrain-pane"#))
        XCTAssertFalse(styles.contains("brightness(0.58)"))
        XCTAssertFalse(styles.contains("grayscale(0.48)"))
        XCTAssertTrue(styles.contains(#"html[data-dark-map-active="true"] #map"#))
        XCTAssertTrue(styles.contains("Native dark tiles are rendered exactly as supplied by the provider."))
    }

    func testFR24PrimaryActionsDrawBeforeNonBlockingAirportSynchronization() throws {
        var workspaceRoot = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 {
            workspaceRoot.deleteLastPathComponent()
        }
        let app = try String(
            contentsOf: workspaceRoot.appendingPathComponent("NavPlanner/Resources/Web/app.js"),
            encoding: .utf8
        )
        let drawStart = try XCTUnwrap(app.range(of: "async function downloadAndDrawFR24Track(key)"))
        let matchStart = try XCTUnwrap(
            app.range(of: "async function matchFR24FlightTrack(key)", range: drawStart.upperBound..<app.endIndex)
        )
        let drawBody = String(app[drawStart.lowerBound..<matchStart.lowerBound])
        let playbackStart = try XCTUnwrap(drawBody.range(of: "const payload = await fetchFR24TrackPayload"))
        let playbackBody = String(drawBody[playbackStart.lowerBound...])
        let trackDraw = try XCTUnwrap(playbackBody.range(of: "drawFR24TrackPoints(payload.track_points || [])"))
        let airportSync = try XCTUnwrap(playbackBody.range(of: "await syncPlanAirportsFromFR24Flight"))
        XCTAssertLessThan(trackDraw.lowerBound, airportSync.lowerBound)
        XCTAssertTrue(playbackBody.contains("if (count < 2)"))
        XCTAssertTrue(playbackBody.contains("FR24 轨迹已绘制，机场同步未完成"))
        XCTAssertTrue(app.contains("FR24 拟合沿用当前查询机场，机场同步未完成"))
        XCTAssertTrue(app.contains("Promise.allSettled(["))
        XCTAssertTrue(app.contains("elements.departureInput.value = optimisticDeparture"))
        XCTAssertTrue(app.contains("elements.arrivalInput.value = optimisticArrival"))
        XCTAssertTrue(app.contains("function isCanonicalAirportCode(value)"))
        XCTAssertTrue(app.contains("originCandidates.find(isCanonicalAirportCode)"))
        XCTAssertTrue(app.contains("destinationCandidates.find(isCanonicalAirportCode)"))
        XCTAssertFalse(app.contains("|| Boolean(payload?.browser_adapter_available)"))

        let matchCurrent = try XCTUnwrap(app.range(of: "async function matchCurrentFR24Track()"))
        let matchCurrentBody = String(app[matchCurrent.lowerBound...])
        let currentTrack = try XCTUnwrap(matchCurrentBody.range(of: "state.fr24TrackPayload?.track_points"))
        let routeInputs = try XCTUnwrap(matchCurrentBody.range(of: "currentQueryRouteInputs()"))
        XCTAssertLessThan(currentTrack.lowerBound, routeInputs.lowerBound)
    }

    func testNativeDarkProviderUsesDedicatedArcGISDarkGrayTiles() throws {
        let provider = try XCTUnwrap(SimNavOnlineTileCache.providers["arcgis-dark"])
        XCTAssertEqual(provider.key, "arcgis-dark")
        XCTAssertEqual(provider.format, "jpg")
        XCTAssertEqual(provider.contentType, "image/jpeg")
        XCTAssertEqual(provider.maxZoom, 20)
        XCTAssertEqual(provider.templates.count, 2)
        XCTAssertTrue(provider.templates.allSatisfy {
            $0.contains("arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/")
        })
        XCTAssertEqual(
            provider.requestURLs(z: 4, x: 13, y: 6).first?.path,
            "/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/4/6/13"
        )
    }

    func testDirectWebKitAndHTTPAdaptersHaveTransportParity() throws {
        let dataRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SimNavCoreTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dataRoot) }
        let router = SimNavRuntimeRouter(configuration: RuntimeConfiguration(dataRoot: dataRoot))

        let direct = RuntimeRequest(method: "GET", path: "/header")
        let url = try XCTUnwrap(URL(string: "navplanner://api/header"))
        let webKitAdapted = RuntimeRequest(urlRequest: URLRequest(url: url))
        let httpAdapted = RuntimeRequest(
            httpMethod: "GET",
            httpTarget: "/api/header",
            httpHeaders: ["Accept": "application/json"]
        )
        let responses = [direct, webKitAdapted, httpAdapted].map { router.handle($0) }
        let directResponse = try XCTUnwrap(responses.first)

        XCTAssertEqual(webKitAdapted.method, "GET")
        XCTAssertEqual(webKitAdapted.path, "/header")
        XCTAssertEqual(httpAdapted.method, "GET")
        XCTAssertEqual(httpAdapted.path, "/api/header")
        XCTAssertTrue(responses.allSatisfy { $0.status == directResponse.status })
        XCTAssertTrue(responses.allSatisfy { $0.headers == directResponse.headers })
        XCTAssertTrue(responses.allSatisfy { $0.contentType == "application/json" })
        XCTAssertEqual(Set(responses.map { bodyHash($0.body) }).count, 1)
        XCTAssertTrue(responses.allSatisfy { $0.body == directResponse.body })
    }

    func testWebKitResponseAdapterProbePreservesRuntimeSemantics() {
        let body = Data((0..<32).map(UInt8.init))
        let runtime = RuntimeResponse(
            status: 206,
            headers: [
                "Cache-Control": "public, max-age=60",
                "Content-Range": "bytes 0-31/64",
                "Content-Type": "application/octet-stream",
                "X-Offline-Map": "HIT"
            ],
            body: body
        )
        let adapted = RuntimeWebKitResponseAdapter.adapt(
            runtime,
            baseHeaders: [
                "Access-Control-Allow-Origin": "*",
                "Cache-Control": "no-store"
            ]
        )

        XCTAssertEqual(adapted.statusCode, runtime.status)
        XCTAssertEqual(adapted.mimeType, runtime.contentType)
        XCTAssertEqual(bodyHash(adapted.data), bodyHash(runtime.body))
        XCTAssertEqual(adapted.headers["Content-Range"], "bytes 0-31/64")
        XCTAssertEqual(adapted.headers["X-Offline-Map"], "HIT")
        XCTAssertEqual(adapted.headers["Access-Control-Allow-Origin"], "*")
        XCTAssertEqual(adapted.headers["Cache-Control"], "public, max-age=60")
        XCTAssertFalse(adapted.headers.keys.contains {
            $0.caseInsensitiveCompare("Content-Type") == .orderedSame
        })
    }

    func testURLRequestAdapterPreservesRepeatedQueryAndBody() throws {
        let url = try XCTUnwrap(URL(string: "navplanner://api/search?q=ZBAA&q=ZSPD"))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{\"value\":1}".utf8)

        let adapted = RuntimeRequest(urlRequest: request)

        XCTAssertEqual(adapted.method, "POST")
        XCTAssertEqual(adapted.query["q"], ["ZBAA", "ZSPD"])
        XCTAssertEqual(adapted.headerValue("content-type"), "application/json")
        XCTAssertEqual(adapted.body, request.httpBody)
    }

    func testHTTPRequestAdapterPreservesRepeatedQueryHeadersAndBody() {
        let body = Data("{\"value\":1}".utf8)
        let adapted = RuntimeRequest(
            httpMethod: "post",
            httpTarget: "/api/search?q=ZBAA&q=ZSPD",
            httpHeaders: ["Content-Type": "application/json"],
            body: body
        )

        XCTAssertEqual(adapted.method, "POST")
        XCTAssertEqual(adapted.path, "/api/search")
        XCTAssertEqual(adapted.query["q"], ["ZBAA", "ZSPD"])
        XCTAssertEqual(adapted.headerValue("content-type"), "application/json")
        XCTAssertEqual(adapted.body, body)
    }

    func testCoreRouteListIsExplicitAndDuplicateFree() {
        let routes = SimNavRuntimeRouter.coreRoutes
        XCTAssertEqual(routes.count, Set(routes).count)
        let expected: Set<RuntimeRouteDescriptor> = [
            .init(method: "GET", path: "/header"),
            .init(method: "GET", path: "/search"),
            .init(method: "GET", path: "/airport/{ident}"),
            .init(method: "GET", path: "/procedure/{type}/{airport}/{procedure}/{transition}"),
            .init(method: "POST", path: "/procedure-preview/{type}/{airport}"),
            .init(method: "GET", path: "/airway/{airway}"),
            .init(method: "GET", path: "/nav-overlay"),
            .init(method: "GET", path: "/route/resolve"),
            .init(method: "POST", path: "/route/track-match"),
            .init(method: "GET", path: "/route/fr24-match"),
            .init(method: "GET", path: "/databases/list"),
            .init(method: "POST", path: "/databases/import"),
            .init(method: "POST", path: "/databases/select"),
            .init(method: "POST", path: "/databases/delete"),
            .init(method: "POST", path: "/databases/restore-bundled"),
            .init(method: "GET", path: "/offline-maps"),
            .init(method: "POST", path: "/offline-maps/import"),
            .init(method: "POST", path: "/offline-maps/select"),
            .init(method: "POST", path: "/offline-maps/delete"),
            .init(method: "POST", path: "/offline-maps/compact"),
            .init(method: "POST", path: "/offline-maps/download"),
            .init(method: "POST", path: "/offline-maps/cancel"),
            .init(method: "GET", path: "/offline-maps/tile/{z}/{x}/{y}"),
            .init(method: "GET", path: "/offline-maps/resource/{name}/{z}/{x}/{y}"),
            .init(method: "GET", path: "/offline-maps/pmtiles/{name}.pmtiles"),
            .init(method: "GET", path: "/map-cache/status"),
            .init(method: "POST", path: "/map-cache/clear"),
            .init(method: "GET", path: "/map-cache/{provider}/{z}/{x}/{y}"),
            .init(method: "GET", path: "/terrain/terrarium/{z}/{x}/{y}.png"),
            .init(method: "GET", path: "/weather/open-meteo"),
            .init(method: "GET", path: "/fr24/cache/status"),
            .init(method: "GET", path: "/fr24/cache/list"),
            .init(method: "GET", path: "/fr24/cache/file/{cacheKey}"),
            .init(method: "POST", path: "/fr24/cache/delete"),
            .init(method: "POST", path: "/fr24/cache/favorite"),
            .init(method: "POST", path: "/fr24/cache/share"),
            .init(method: "POST", path: "/fr24/cache/clear"),
            .init(method: "GET", path: "/fr24/access/status"),
            .init(method: "POST", path: "/fr24/access/probe"),
            .init(method: "POST", path: "/fr24/access/update"),
            .init(method: "POST", path: "/fr24/access/clear"),
            .init(method: "POST", path: "/fr24/browser/open"),
            .init(method: "POST", path: "/fr24/browser/sync"),
            .init(method: "GET", path: "/fr24/browser/status"),
            .init(method: "GET", path: "/fr24/search"),
            .init(method: "GET", path: "/fr24/history"),
            .init(method: "GET", path: "/fr24/manual-history"),
            .init(method: "POST", path: "/fr24/download")
        ]
        XCTAssertEqual(Set(routes), expected)
    }

    func testFR24SessionFileIsIsolatedSanitizedAndPrivate() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "SimNavFR24SessionTests-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let fileURL = root.appendingPathComponent("Config/fr24-session.json")
        let preferences = FR24SessionPreferences(fileURL: fileURL)

        let updated = FR24SessionStore.updateAccessPayload(
            webCookie: "Cookie: session=value\r\nInjected: rejected",
            frPl: "token\tvalue",
            userDefaults: preferences
        )
        XCTAssertEqual(updated["access_state"] as? String, "configured")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertEqual(
            FR24SessionStore.storedWebCookie(userDefaults: preferences),
            "session=value Injected: rejected"
        )
        XCTAssertEqual(
            FR24SessionStore.storedFRPl(userDefaults: preferences),
            "token value"
        )

        let reloaded = FR24SessionPreferences(fileURL: fileURL)
        XCTAssertEqual(
            FR24SessionStore.requestCookieHeader(userDefaults: reloaded),
            "session=value Injected: rejected; _frPl=token value"
        )
#if !os(Windows)
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let permissions = (attributes[.posixPermissions] as? NSNumber)?.intValue
        XCTAssertEqual(permissions, 0o600)
#endif

        let cleared = FR24SessionStore.clearAccessPayload(userDefaults: reloaded)
        XCTAssertEqual(cleared["access_state"] as? String, "unknown")
        XCTAssertNil(FR24SessionStore.requestCookieHeader(userDefaults: reloaded))
    }

    func testLocalWebFR24PayloadDoesNotExposeFilesystemPaths() throws {
        let dataRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
            "SimNavFR24PrivacyTests-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: dataRoot) }
        let router = SimNavRuntimeRouter(configuration: RuntimeConfiguration(dataRoot: dataRoot))

        let response = router.handle(RuntimeRequest(method: "GET", path: "/fr24/cache/status"))
        XCTAssertEqual(response.status, 200)
        let payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: response.body) as? [String: Any]
        )

        XCTAssertNil(payload["root"])
        XCTAssertFalse(String(decoding: response.body, as: UTF8.self).contains(dataRoot.path))
    }

    func testManagedBrowserFR24CompletesZBAAToZULSQueryDownloadAndTrackMatch() throws {
        var workspaceRoot = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 {
            workspaceRoot.deleteLastPathComponent()
        }
        let databaseURL = [
            workspaceRoot.appendingPathComponent("database/e_dfd_PMDG_release.s3db"),
            workspaceRoot.appendingPathComponent("NavPlanner/Resources/Database/navdata.sqlite")
        ].first { FileManager.default.fileExists(atPath: $0.path) }
        guard let databaseURL else {
            throw XCTSkip("Local ignored navigation database is not available.")
        }

        let dataRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
            "SimNavManagedBrowserFR24Tests-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: dataRoot) }
        let browser = ManagedBrowserFR24Fixture()
        let router = SimNavRuntimeRouter(
            configuration: RuntimeConfiguration(
                dataRoot: dataRoot,
                bundledDatabaseURL: databaseURL
            ),
            fr24BrowserFetcher: browser
        )

        let opened = try jsonObject(router.handle(RuntimeRequest(
            method: "POST",
            path: "/fr24/browser/open"
        )))
        XCTAssertEqual(opened["opened"] as? Bool, true)
        XCTAssertEqual(opened["access_method"] as? String, "managed_browser")
        XCTAssertEqual(
            (opened["access"] as? [String: Any])?["access_method"] as? String,
            "managed_browser"
        )

        let synced = try jsonObject(router.handle(RuntimeRequest(
            method: "POST",
            path: "/fr24/browser/sync"
        )))
        XCTAssertEqual(synced["verified"] as? Bool, true)
        XCTAssertEqual(synced["access_state"] as? String, "available")
        XCTAssertEqual(synced["access_method"] as? String, "managed_browser")

        let search = try jsonObject(router.handle(RuntimeRequest(
            method: "GET",
            path: "/fr24/search",
            query: [
                "departure": ["ZBAA"],
                "arrival": ["ZULS"],
                "limit": ["10"]
            ]
        )))
        let flights = try XCTUnwrap(search["flights"] as? [[String: Any]])
        let flight = try XCTUnwrap(flights.first)
        XCTAssertEqual(flight["fr24_id"] as? String, ManagedBrowserFR24Fixture.flightID)
        XCTAssertEqual(flight["flight"] as? String, "CA4123")
        XCTAssertEqual(flight["origin_icao"] as? String, "ZBAA")
        XCTAssertEqual(flight["dest_icao"] as? String, "ZULS")

        let downloadBody = try JSONSerialization.data(withJSONObject: [
            "flight_id": ManagedBrowserFR24Fixture.flightID,
            "flight": flight
        ])
        let downloadResponse = router.handle(RuntimeRequest(
            method: "POST",
            path: "/fr24/download",
            headers: ["Content-Type": "application/json"],
            body: downloadBody
        ))
        XCTAssertEqual(downloadResponse.status, 200)
        let download = try jsonObject(downloadResponse)
        let trackPoints = try XCTUnwrap(download["track_points"] as? [[String: Any]])
        XCTAssertEqual(trackPoints.count, 14)
        XCTAssertEqual(download["track_point_count"] as? Int, 14)
        XCTAssertEqual(download["cache_hit"] as? Bool, false)

        let matchBody = try JSONSerialization.data(withJSONObject: [
            "departure": "ZBAA",
            "arrival": "ZULS",
            "track_points": trackPoints
        ])
        let matchResponse = router.handle(RuntimeRequest(
            method: "POST",
            path: "/route/track-match",
            headers: ["Content-Type": "application/json"],
            body: matchBody
        ))
        XCTAssertEqual(matchResponse.status, 200)
        let match = try jsonObject(matchResponse)
        XCTAssertNil(match["error"])
        XCTAssertGreaterThanOrEqual((match["points"] as? [[String: Any]])?.count ?? 0, 35)
        XCTAssertGreaterThanOrEqual((match["legs"] as? [[String: Any]])?.count ?? 0, 7)
        let matchedDistance = try XCTUnwrap(match["distance_nm"] as? Double)
        XCTAssertGreaterThan(matchedDistance, 1_500)
        XCTAssertLessThan(matchedDistance, 1_750)
        if databaseURL.lastPathComponent == "e_dfd_PMDG_release.s3db" {
            XCTAssertEqual(matchedDistance, 1674.938876470219, accuracy: 0.01)
        }

        let cache = try jsonObject(router.handle(RuntimeRequest(
            method: "GET",
            path: "/fr24/cache/list",
            query: ["query": ["CA4123"]]
        )))
        let cachedItems = try XCTUnwrap(cache["items"] as? [[String: Any]])
        XCTAssertEqual(cachedItems.count, 1)
        XCTAssertEqual(cachedItems.first?["fr24_id"] as? String, ManagedBrowserFR24Fixture.flightID)

        let serializedPayloads = [opened, synced, search, download, match, cache]
            .compactMap { try? JSONSerialization.data(withJSONObject: $0, options: [.sortedKeys]) }
            .map { String(decoding: $0, as: UTF8.self) }
            .joined(separator: "\n")
        XCTAssertFalse(serializedPayloads.localizedCaseInsensitiveContains("api_token"))
        XCTAssertFalse(serializedPayloads.localizedCaseInsensitiveContains("bearer"))
        XCTAssertTrue(browser.requestedPaths.contains("/common/v1/airport.json"))
        XCTAssertTrue(browser.requestedPaths.contains("/common/v1/flight-playback.json"))
    }

    func testFR24AirportCodesAreCanonicalizedToDatabaseICAO() throws {
        var workspaceRoot = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 {
            workspaceRoot.deleteLastPathComponent()
        }
        let databaseURL = [
            workspaceRoot.appendingPathComponent("database/e_dfd_PMDG_release.s3db"),
            workspaceRoot.appendingPathComponent("NavPlanner/Resources/Database/navdata.sqlite")
        ].first { FileManager.default.fileExists(atPath: $0.path) }
        guard let databaseURL else {
            throw XCTSkip("Local ignored navigation database is not available.")
        }

        let service = PlannerService(dataStore: LocalDataStore(databaseURL: databaseURL))
        let canonical = service.canonicalizedFR24FlightAirports([
            "origin_icao": "",
            "origin_iata": "PEK",
            "origin_actual_code": "PEK",
            "dest_icao": "",
            "dest_iata": "LXA",
            "dest_actual_code": "LXA"
        ])
        XCTAssertEqual(canonical["origin_icao"] as? String, "ZBAA")
        XCTAssertEqual(canonical["origin_actual_code"] as? String, "ZBAA")
        XCTAssertEqual(canonical["origin_iata"] as? String, "PEK")
        XCTAssertEqual(canonical["dest_icao"] as? String, "ZULS")
        XCTAssertEqual(canonical["dest_actual_code"] as? String, "ZULS")
        XCTAssertEqual(canonical["dest_iata"] as? String, "LXA")

        let unresolved = service.canonicalizedFR24FlightAirports([
            "origin_icao": "ZBAA",
            "origin_iata": "PEK",
            "origin_actual_code": "PEK",
            "dest_icao": "ZULS",
            "dest_iata": "LXA",
            "dest_actual_code": "XYZ"
        ])
        XCTAssertEqual(unresolved["origin_actual_code"] as? String, "ZBAA")
        XCTAssertEqual(unresolved["dest_icao"] as? String, "ZULS")
        XCTAssertNil(unresolved["dest_actual_code"])
        XCTAssertEqual(unresolved["dest_actual_iata"] as? String, "XYZ")

        let turpan = service.canonicalizedFR24FlightAirports([
            "origin_icao": "ZBAD",
            "origin_iata": "PKX",
            "dest_icao": "",
            "dest_iata": "TLQ",
            "dest_actual_code": "TLQ"
        ])
        XCTAssertEqual(turpan["origin_icao"] as? String, "ZBAD")
        XCTAssertEqual(turpan["dest_icao"] as? String, "ZWTL")
        XCTAssertEqual(turpan["dest_actual_code"] as? String, "ZWTL")

        let routeAirports = service.fr24RouteAirportsPayload(
            departure: "ZBAD",
            arrival: "ZWTL"
        )
        XCTAssertNil(routeAirports["error"])
        let arrival = try XCTUnwrap(routeAirports["arrival"] as? [String: Any])
        XCTAssertEqual(arrival["ident"] as? String, "ZW01")
        XCTAssertEqual(arrival["icao"] as? String, "ZWTL")
        XCTAssertEqual(arrival["iata"] as? String, "TLQ")
        XCTAssertEqual(arrival["schedule_code"] as? String, "TLQ")
    }

    func testDirectRouterCoreSmokeWithDevelopmentDatabase() throws {
        var workspaceRoot = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 {
            workspaceRoot.deleteLastPathComponent()
        }
        let databaseURL = workspaceRoot
            .appendingPathComponent("NavPlanner/Resources/Database/navdata.sqlite")
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            throw XCTSkip("Local ignored navigation database is not available.")
        }

        let dataStore = LocalDataStore(databaseURL: databaseURL)
        let service = PlannerService(dataStore: dataStore)
        let router = SimNavRuntimeRouter(plannerService: service)

        let searchResponse = router.handle(RuntimeRequest(
            method: "GET",
            path: "/api/search",
            query: ["q": ["ZBAA"]]
        ))
        XCTAssertEqual(searchResponse.status, 200)
        let searchPayload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: searchResponse.body) as? [String: Any]
        )
        let searchResults = try XCTUnwrap(searchPayload["results"] as? [[String: Any]])
        XCTAssertEqual(searchResults.first?["ident"] as? String, "ZBAA")

        let airportResponse = router.handle(RuntimeRequest(
            method: "GET",
            path: "/airport/ZBAA"
        ))
        XCTAssertEqual(airportResponse.status, 200)
        let airportPayload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: airportResponse.body) as? [String: Any]
        )
        let airport = try XCTUnwrap(airportPayload["airport"] as? [String: Any])
        XCTAssertEqual(airport["airport_identifier"] as? String, "ZBAA")

        let errorResponse = router.handle(RuntimeRequest(
            method: "GET",
            path: "/route/resolve",
            query: [
                "departure": ["KLAX"],
                "arrival": ["KPSP"],
                "route": ["DCT GARNE"]
            ]
        ))
        XCTAssertEqual(errorResponse.status, 400)
        let errorPayload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: errorResponse.body) as? [String: Any]
        )
        XCTAssertEqual(errorPayload["error"] as? String, "DCT must follow a known fix or airport.")
    }

    private func bodyHash(_ data: Data) -> String {
        let value = data.reduce(UInt64(0xcbf29ce484222325)) { partial, byte in
            (partial ^ UInt64(byte)) &* 0x100000001b3
        }
        return String(format: "%016llx", value)
    }

    private func jsonObject(_ response: RuntimeResponse) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: response.body) as? [String: Any])
    }
}

private final class ManagedBrowserFR24Fixture: FR24BrowserFetching, FR24BrowserSessionManaging {
    static let flightID = "40fc18c8"

    private let lock = NSLock()
    private var requestedPathsStorage: [String] = []
    private var opened = false

    var requestedPaths: [String] {
        lock.lock()
        defer { lock.unlock() }
        return requestedPathsStorage
    }

    func openVerificationPage() throws -> [String: Any] {
        lock.lock()
        opened = true
        lock.unlock()
        return [
            "opened": true,
            "access_method": "managed_browser",
            "isolated_profile": true,
            "message": "Fixture verification page opened."
        ]
    }

    func browserSessionStatusPayload() -> [String: Any] {
        lock.lock()
        let isOpened = opened
        lock.unlock()
        return [
            "available": true,
            "running": isOpened,
            "isolated_profile": true,
            "browser": "Fixture Chromium",
            "verification_opened": isOpened
        ]
    }

    func clearBrowserSession() throws {
        lock.lock()
        opened = false
        lock.unlock()
    }

    func performJSONRequest(path: String, params: [(String, String)]) throws -> [String: Any] {
        lock.lock()
        requestedPathsStorage.append(path)
        lock.unlock()
        if path == "/common/v1/airport.json" {
            if params.contains(where: { $0.0 == "plugin-setting[schedule][timestamp]" }) {
                throw NSError(
                    domain: "ManagedBrowserFR24Fixture",
                    code: 400,
                    userInfo: [NSLocalizedDescriptionKey: "FR24 web returned HTTP 400."]
                )
            }
            return Self.schedulePayload
        }
        if path == "/common/v1/flight-playback.json" {
            return Self.playbackPayload
        }
        throw NSError(
            domain: "ManagedBrowserFR24Fixture",
            code: 404,
            userInfo: [NSLocalizedDescriptionKey: "Unexpected fixture path: \(path)"]
        )
    }

    func performFlightHistoryPageRequest(flightToken: String) throws -> [String: Any] {
        ["title": flightToken, "url": "https://www.flightradar24.com/data/flights/\(flightToken)", "rows": []]
    }

    private static let schedulePayload: [String: Any] = [
        "result": [
            "response": [
                "airport": [
                    "pluginData": [
                        "schedule": [
                            "departures": [
                                "data": [[
                                    "flight": [
                                        "identification": [
                                            "id": flightID,
                                            "number": ["default": "CA4123"],
                                            "callsign": "CCA4123"
                                        ],
                                        "airline": ["name": "Air China"],
                                        "aircraft": [
                                            "model": ["code": "A359"],
                                            "registration": "B-32NH"
                                        ],
                                        "airport": [
                                            "origin": [
                                                "code": ["icao": "ZBAA", "iata": "PEK"],
                                                "name": "Beijing Capital"
                                            ],
                                            "destination": [
                                                "code": ["icao": "ZULS", "iata": "LXA"],
                                                "name": "Lhasa Gonggar"
                                            ]
                                        ],
                                        "time": [
                                            "scheduled": ["departure": 1_786_580_000, "arrival": 1_786_591_700],
                                            "real": ["departure": 1_786_580_000, "arrival": 1_786_591_700]
                                        ],
                                        "status": ["text": "Landed"]
                                    ]
                                ]]
                            ]
                        ]
                    ]
                ]
            ]
        ]
    ]

    private static let playbackPayload: [String: Any] = [
        "flight": schedulePayload,
        "track": [
            ["lat": 40.07333333, "lon": 116.59833333, "altitude": 1_000, "speed": 180, "timestamp": 1_786_580_000],
            ["lat": 38.75888889, "lon": 114.97777778, "altitude": 3_200, "speed": 210, "timestamp": 1_786_580_900],
            ["lat": 38.31638889, "lon": 113.81555556, "altitude": 6_400, "speed": 240, "timestamp": 1_786_581_800],
            ["lat": 37.32694444, "lon": 111.73750000, "altitude": 9_600, "speed": 270, "timestamp": 1_786_582_700],
            ["lat": 34.50472222, "lon": 108.55166667, "altitude": 12_800, "speed": 300, "timestamp": 1_786_583_600],
            ["lat": 33.41388889, "lon": 108.08805556, "altitude": 16_000, "speed": 330, "timestamp": 1_786_584_500],
            ["lat": 32.30527778, "lon": 106.67444444, "altitude": 19_200, "speed": 360, "timestamp": 1_786_585_400],
            ["lat": 31.04805556, "lon": 104.66722222, "altitude": 22_400, "speed": 390, "timestamp": 1_786_586_300],
            ["lat": 30.64500000, "lon": 103.68666667, "altitude": 25_600, "speed": 420, "timestamp": 1_786_587_200],
            ["lat": 30.78277778, "lon": 101.90277778, "altitude": 28_800, "speed": 420, "timestamp": 1_786_588_100],
            ["lat": 31.14666667, "lon": 97.17666667, "altitude": 32_000, "speed": 420, "timestamp": 1_786_589_000],
            ["lat": 30.51083333, "lon": 94.19805556, "altitude": 35_000, "speed": 420, "timestamp": 1_786_589_900],
            ["lat": 29.82888889, "lon": 91.82222222, "altitude": 35_000, "speed": 420, "timestamp": 1_786_590_800],
            ["lat": 29.29666667, "lon": 90.91166667, "altitude": 35_000, "speed": 420, "timestamp": 1_786_591_700]
        ]
    ]
}
