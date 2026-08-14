import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if !os(Windows)
import Hummingbird
import HummingbirdTesting
import HTTPTypes
#if canImport(SQLite3)
import SQLite3
#elseif canImport(CSQLite)
import CSQLite
#endif
import XCTest
@testable import SimNavLocalWeb
import SimNavCore

final class LocalWebHTTPServerTests: XCTestCase {
    private let token = "0123456789abcdef0123456789abcdef"

    func testBindHostRequiresExplicitContainerBoundary() throws {
        let webRoot = workspaceRoot().appendingPathComponent("NavPlanner/Resources/Web")
        let dataRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
            "SimNavBindHostTests-\(UUID().uuidString)",
            isDirectory: true
        )
        let baseEnvironment = [
            "SIMNAV_WRITE_TOKEN": token,
            "SIMNAV_DATA_DIR": dataRoot.path
        ]
        let arguments = ["--web-root", webRoot.path]

        XCTAssertEqual(
            try LocalWebSettings.load(arguments: arguments, environment: baseEnvironment).bindHost,
            "127.0.0.1"
        )

        var containerEnvironment = baseEnvironment
        containerEnvironment["SIMNAV_CONTAINER"] = "1"
        containerEnvironment["SIMNAV_BIND_HOST"] = "0.0.0.0"
        XCTAssertEqual(
            try LocalWebSettings.load(arguments: arguments, environment: containerEnvironment).bindHost,
            "0.0.0.0"
        )

        var unsafeEnvironment = baseEnvironment
        unsafeEnvironment["SIMNAV_BIND_HOST"] = "0.0.0.0"
        XCTAssertThrowsError(
            try LocalWebSettings.load(arguments: arguments, environment: unsafeEnvironment)
        ) { error in
            guard case LocalWebSettingsError.invalidBindHost("0.0.0.0") = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testPackagedDatabaseIsDiscoveredBesideCanonicalWebRoot() throws {
        let packageRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
            "SimNavPackagedDatabaseTests-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: packageRoot) }
        let resourcesRoot = packageRoot.appendingPathComponent("Resources", isDirectory: true)
        let webRoot = resourcesRoot.appendingPathComponent("Web", isDirectory: true)
        let databaseRoot = resourcesRoot.appendingPathComponent("Database", isDirectory: true)
        let bundledDatabase = databaseRoot.appendingPathComponent("navdata.sqlite")
        try FileManager.default.createDirectory(at: webRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: databaseRoot, withIntermediateDirectories: true)
        try Data("<title>SimNav Studio</title>".utf8).write(
            to: webRoot.appendingPathComponent("map.html")
        )
        try Data().write(to: bundledDatabase)

        let settings = try LocalWebSettings.load(
            arguments: ["--web-root", webRoot.path],
            environment: [
                "SIMNAV_DATA_DIR": packageRoot.appendingPathComponent("Data").path,
                "SIMNAV_WRITE_TOKEN": token
            ]
        )

        XCTAssertEqual(settings.bundledDatabaseURL, bundledDatabase.standardizedFileURL)
    }

    func testHTTPAdapterMatchesDirectRuntimeBodyAndHeaders() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.dataRoot) }
        let server = LocalWebHTTPServer(settings: fixture.settings)
        let app = Application(router: server.buildRouter())
        let direct = server.runtimeRouter.handle(RuntimeRequest(
            method: "GET",
            path: "/api/header"
        ))

        try await app.test(.router) { client in
            let response = try await client.execute(uri: "/api/header", method: .get)
            XCTAssertEqual(response.status.code, direct.status)
            XCTAssertEqual(response.headers[.contentType], direct.headers["Content-Type"])
            XCTAssertEqual(response.headers[.cacheControl], direct.headers["Cache-Control"])
            XCTAssertEqual(Data(response.body.readableBytesView), direct.body)
        }
    }

    func testSharedWebRootAndWriteTokenInjection() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.dataRoot) }
        let server = LocalWebHTTPServer(settings: fixture.settings)
        let app = Application(router: server.buildRouter())

        try await app.test(.router) { client in
            let index = try await client.execute(uri: "/", method: .get)
            let indexData = Data(index.body.readableBytesView)
            let html = String(decoding: indexData, as: UTF8.self)
            let sourceHTML = try String(
                contentsOf: fixture.settings.webRoot.appendingPathComponent("map.html"),
                encoding: .utf8
            ).replacingOccurrences(of: "__SIMNAV_WRITE_TOKEN__", with: token)
            XCTAssertEqual(index.status, .ok)
            XCTAssertEqual(index.headers[.contentType], "text/html; charset=utf-8")
            XCTAssertEqual(indexData, Data(sourceHTML.utf8))
            XCTAssertTrue(html.contains("SimNav Studio"))
            XCTAssertTrue(html.contains(token))
            XCTAssertFalse(html.contains("__SIMNAV_WRITE_TOKEN__"))
            XCTAssertTrue(html.contains(#"window.location.protocol === "navplanner:""#))
            XCTAssertTrue(html.contains(#"window.location.protocol === "file:""#))
            XCTAssertTrue(html.contains(#"usesAppleResourceBridge ? "navplanner://app/" : "/""#))
            XCTAssertTrue(html.contains("20260814-native-dark-map-style2-v108"))
            XCTAssertTrue(html.contains(#"href="/app-icons/style2-day-medium.png""#))
            XCTAssertTrue(html.contains(#"id="darkMapToggle" type="checkbox""#))
            XCTAssertFalse(html.contains(#"id="darkMapToggle" type="checkbox" checked"#))

            let script = try await client.execute(uri: "/app.js", method: .get)
            let scriptData = Data(script.body.readableBytesView)
            let sourceScript = try Data(
                contentsOf: fixture.settings.webRoot.appendingPathComponent("app.js")
            )
            XCTAssertEqual(script.status, .ok)
            XCTAssertEqual(scriptData, sourceScript)
            XCTAssertTrue(String(decoding: scriptData, as: UTF8.self).contains(#"providerKey: "arcgis-dark""#))

            let runtimeScript = try await client.execute(uri: "/runtime.js", method: .get)
            let runtimeData = Data(runtimeScript.body.readableBytesView)
            let sourceRuntime = try Data(
                contentsOf: fixture.settings.webRoot.appendingPathComponent("runtime.js")
            )
            XCTAssertEqual(runtimeScript.status, .ok)
            XCTAssertEqual(runtimeData, sourceRuntime)
            XCTAssertTrue(String(decoding: runtimeData, as: UTF8.self)
                .contains("window.SimNavRuntime"))

            let uiZoomScript = try await client.execute(uri: "/ui-zoom.js", method: .get)
            let uiZoomData = Data(uiZoomScript.body.readableBytesView)
            let sourceUIZoom = try Data(
                contentsOf: fixture.settings.webRoot.appendingPathComponent("ui-zoom.js")
            )
            XCTAssertEqual(uiZoomScript.status, .ok)
            XCTAssertEqual(uiZoomData, sourceUIZoom)
            let uiZoomSource = String(decoding: uiZoomData, as: UTF8.self)
            XCTAssertTrue(uiZoomSource.contains("window.SimNavUIZoom"))
            XCTAssertTrue(uiZoomSource.contains("return 0.9"))
            XCTAssertTrue(uiZoomSource.contains("1 + normalizeLevel(value) * 0.08"))
            XCTAssertLessThan(
                try XCTUnwrap(html.range(of: "src=\"/ui-zoom.js\"")?.lowerBound),
                try XCTUnwrap(html.range(of: "href=\"/styles.css\"")?.lowerBound)
            )
            XCTAssertLessThan(
                try XCTUnwrap(html.range(of: "src=\"/runtime.js\"")?.lowerBound),
                try XCTUnwrap(html.range(of: "src=\"/app.js\"")?.lowerBound)
            )
        }
    }

    func testManagedBrowserFR24RoutesRequireWriteTokenAndPreserveTransportPayload() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.dataRoot) }
        let browser = HTTPManagedBrowserFR24Fixture()
        let server = LocalWebHTTPServer(
            settings: fixture.settings,
            fr24BrowserFetcher: browser
        )
        let app = Application(router: server.buildRouter())

        try await app.test(.router) { client in
            let rejected = try await client.execute(
                uri: "/api/fr24/browser/open",
                method: .post
            )
            XCTAssertEqual(rejected.status, .forbidden)

            var headers: HTTPFields = [:]
            headers[try XCTUnwrap(HTTPField.Name("X-SimNav-Token"))] = token
            let opened = try await client.execute(
                uri: "/api/fr24/browser/open",
                method: .post,
                headers: headers
            )
            XCTAssertEqual(opened.status, .ok)
            let openedPayload = try XCTUnwrap(
                JSONSerialization.jsonObject(with: Data(opened.body.readableBytesView)) as? [String: Any]
            )
            XCTAssertEqual(openedPayload["opened"] as? Bool, true)
            XCTAssertEqual(openedPayload["access_method"] as? String, "managed_browser")

            let synced = try await client.execute(
                uri: "/api/fr24/browser/sync",
                method: .post,
                headers: headers
            )
            XCTAssertEqual(synced.status, .ok)
            let syncedPayload = try XCTUnwrap(
                JSONSerialization.jsonObject(with: Data(synced.body.readableBytesView)) as? [String: Any]
            )
            XCTAssertEqual(syncedPayload["verified"] as? Bool, true)
            XCTAssertEqual(syncedPayload["access_method"] as? String, "managed_browser")

            let status = try await client.execute(
                uri: "/api/fr24/browser/status",
                method: .get
            )
            XCTAssertEqual(status.status, .ok)
            let statusBody = String(decoding: status.body.readableBytesView, as: UTF8.self)
            XCTAssertTrue(statusBody.contains("managed_browser"))
            XCTAssertFalse(statusBody.localizedCaseInsensitiveContains("api_token"))
            XCTAssertEqual(browser.openCount, 1)
            XCTAssertGreaterThanOrEqual(browser.requestCount, 1)
        }
    }

#if os(macOS)
    func testRealChromiumAdapterCompletesZBAAToZULSChainAgainstLocalUpstream() async throws {
        let executable = [
            "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
            "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
            "/Applications/Chromium.app/Contents/MacOS/Chromium"
        ].first { FileManager.default.isExecutableFile(atPath: $0) }
        guard let executable else {
            throw XCTSkip("Chrome, Edge, or Chromium is not installed for the CDP integration probe.")
        }

        let upstreamRouter = Router()
        upstreamRouter.get("/**") { request, _ -> Response in
            let target = request.uri.string
            let body: String
            let contentType: String
            let status: HTTPResponse.Status
            let isDataRequest = target.contains("/common/v1/flight-playback.json")
                || target.contains("/common/v1/airport.json")
            let hasWebKitEquivalentHeaders = request.headers[.referer]?.contains("localhost:") == true
                && request.headers[.cacheControl]?.localizedCaseInsensitiveContains("no-cache") == true
            if isDataRequest && !hasWebKitEquivalentHeaders {
                body = #"{"error":"missing WebKit-equivalent navigation headers"}"#
                contentType = "application/json; charset=utf-8"
                status = .forbidden
            } else if target.contains("/common/v1/flight-playback.json") {
                body = CDPFR24Fixture.playbackJSON
                contentType = "application/json; charset=utf-8"
                status = .ok
            } else if target.contains("plugin-setting%5Bschedule%5D%5Btimestamp%5D")
                || target.contains("plugin-setting[schedule][timestamp]") {
                body = #"{"error":"pagination end"}"#
                contentType = "application/json; charset=utf-8"
                status = .badRequest
            } else if target.contains("/common/v1/airport.json") {
                body = CDPFR24Fixture.scheduleJSON
                contentType = "application/json; charset=utf-8"
                status = .ok
            } else {
                body = "<html><head><title>Fixture FR24</title></head><body>FR24 fixture ready</body></html>"
                contentType = "text/html; charset=utf-8"
                status = .ok
            }
            var headers: HTTPFields = [:]
            headers[.contentType] = contentType
            return Response(
                status: status,
                headers: headers,
                body: .init(byteBuffer: ByteBuffer(string: body))
            )
        }
        let upstream = Application(router: upstreamRouter)

        try await upstream.test(.live) { client in
            let port = try XCTUnwrap(client.port)
            let baseURL = try XCTUnwrap(URL(string: "http://localhost:\(port)"))
            let dataRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
                "SimNavCDPFR24Tests-\(UUID().uuidString)",
                isDirectory: true
            )
            defer { try? FileManager.default.removeItem(at: dataRoot) }
            let browser = LocalWebFR24BrowserFetch(configuration: .init(
                profileRoot: dataRoot.appendingPathComponent("FR24Browser", isDirectory: true),
                browserExecutableURL: URL(fileURLWithPath: executable),
                apiBaseURL: baseURL,
                websiteBaseURL: baseURL,
                launchHeadless: true
            ))
            defer { try? browser.clearBrowserSession() }

            let databaseURL = [
                workspaceRoot().appendingPathComponent("database/e_dfd_PMDG_release.s3db"),
                workspaceRoot().appendingPathComponent("NavPlanner/Resources/Database/navdata.sqlite")
            ].first { FileManager.default.fileExists(atPath: $0.path) }
            guard let databaseURL else {
                throw XCTSkip("Local ignored navigation database is not available.")
            }
            let router = SimNavRuntimeRouter(
                configuration: RuntimeConfiguration(
                    dataRoot: dataRoot,
                    bundledDatabaseURL: databaseURL
                ),
                fr24BrowserFetcher: browser
            )

            func payload(_ request: RuntimeRequest) throws -> [String: Any] {
                let response = router.handle(request)
                XCTAssertEqual(response.status, 200, String(decoding: response.body, as: UTF8.self))
                return try XCTUnwrap(
                    JSONSerialization.jsonObject(with: response.body) as? [String: Any]
                )
            }

            let opened = try payload(RuntimeRequest(method: "POST", path: "/fr24/browser/open"))
            XCTAssertEqual(opened["opened"] as? Bool, true)
            let synced = try payload(RuntimeRequest(method: "POST", path: "/fr24/browser/sync"))
            XCTAssertEqual(synced["verified"] as? Bool, true)

            let search = try payload(RuntimeRequest(
                method: "GET",
                path: "/fr24/search",
                query: [
                    "departure": ["ZBAA"],
                    "arrival": ["ZULS"],
                    "limit": ["10"]
                ]
            ))
            let flight = try XCTUnwrap((search["flights"] as? [[String: Any]])?.first)
            XCTAssertEqual(flight["fr24_id"] as? String, "40fc18c8")

            let downloadBody = try JSONSerialization.data(withJSONObject: [
                "flight_id": "40fc18c8",
                "flight": flight
            ])
            let download = try payload(RuntimeRequest(
                method: "POST",
                path: "/fr24/download",
                headers: ["Content-Type": "application/json"],
                body: downloadBody
            ))
            let trackPoints = try XCTUnwrap(download["track_points"] as? [[String: Any]])
            XCTAssertEqual(trackPoints.count, 14)

            let matchBody = try JSONSerialization.data(withJSONObject: [
                "departure": "ZBAA",
                "arrival": "ZULS",
                "track_points": trackPoints
            ])
            let match = try payload(RuntimeRequest(
                method: "POST",
                path: "/route/track-match",
                headers: ["Content-Type": "application/json"],
                body: matchBody
            ))
            XCTAssertGreaterThanOrEqual((match["points"] as? [[String: Any]])?.count ?? 0, 35)
            XCTAssertGreaterThanOrEqual((match["legs"] as? [[String: Any]])?.count ?? 0, 7)
            XCTAssertGreaterThan(try XCTUnwrap(match["distance_nm"] as? Double), 1_500)
        }
    }

    func testRealChromiumAdapterKeepsHomepageVisibleAndClosesDataChallenge() async throws {
        let executable = [
            "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
            "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
            "/Applications/Chromium.app/Contents/MacOS/Chromium"
        ].first { FileManager.default.isExecutableFile(atPath: $0) }
        guard let executable else {
            throw XCTSkip("Chrome, Edge, or Chromium is not installed for the CDP challenge probe.")
        }

        let fixtureResponse: @Sendable (HTTPResponse.Status, String, String) -> Response = {
            status, contentType, body in
            var headers: HTTPFields = [:]
            headers[.contentType] = contentType
            return Response(
                status: status,
                headers: headers,
                body: .init(byteBuffer: ByteBuffer(string: body))
            )
        }
        let upstreamRouter = Router()
        upstreamRouter.get("/") { _, _ in
            fixtureResponse(
                .ok,
                "text/html; charset=utf-8",
                "<html><head><title>FR24 Homepage Fixture</title><script>document.title='webdriver-'+String(navigator.webdriver)</script></head><body>FR24 homepage ready</body></html>"
            )
        }
        upstreamRouter.get("/**") { request, _ in
            if request.uri.path.hasSuffix("/common/v1/airport.json") {
                return fixtureResponse(
                    .forbidden,
                    "text/html; charset=utf-8",
                    "<html><head><title>Just a moment</title></head><body>Cloudflare challenge-platform verification</body></html>"
                )
            }
            return fixtureResponse(
                .ok,
                "text/html; charset=utf-8",
                "<html><head><title>FR24 Homepage Fixture</title><script>document.title='webdriver-'+String(navigator.webdriver)</script></head><body>FR24 homepage ready</body></html>"
            )
        }
        let upstream = Application(router: upstreamRouter)

        try await upstream.test(.live) { client in
            let port = try XCTUnwrap(client.port)
            let baseURL = try XCTUnwrap(URL(string: "http://localhost:\(port)"))
            let dataRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
                "SimNavCDPFR24ChallengeTests-\(UUID().uuidString)",
                isDirectory: true
            )
            defer { try? FileManager.default.removeItem(at: dataRoot) }
            let profileRoot = dataRoot.appendingPathComponent("FR24Browser", isDirectory: true)
            let browser = LocalWebFR24BrowserFetch(configuration: .init(
                profileRoot: profileRoot,
                browserExecutableURL: URL(fileURLWithPath: executable),
                apiBaseURL: baseURL,
                websiteBaseURL: baseURL,
                launchHeadless: false,
                additionalBrowserArguments: [
                    "--window-position=-10000,-10000",
                    "--window-size=800,600"
                ]
            ))
            defer { try? browser.clearBrowserSession() }

            let databaseURL = [
                workspaceRoot().appendingPathComponent("database/e_dfd_PMDG_release.s3db"),
                workspaceRoot().appendingPathComponent("NavPlanner/Resources/Database/navdata.sqlite")
            ].first { FileManager.default.fileExists(atPath: $0.path) }
            guard let databaseURL else {
                throw XCTSkip("Local ignored navigation database is not available.")
            }
            let router = SimNavRuntimeRouter(
                configuration: RuntimeConfiguration(
                    dataRoot: dataRoot,
                    bundledDatabaseURL: databaseURL
                ),
                fr24BrowserFetcher: browser
            )

            let opened = router.handle(RuntimeRequest(method: "POST", path: "/fr24/browser/open"))
            XCTAssertEqual(opened.status, 200, String(decoding: opened.body, as: UTF8.self))
            let synced = router.handle(RuntimeRequest(method: "POST", path: "/fr24/browser/sync"))
            XCTAssertEqual(synced.status, 503, String(decoding: synced.body, as: UTF8.self))
            let syncPayload = try XCTUnwrap(
                JSONSerialization.jsonObject(with: synced.body) as? [String: Any]
            )
            XCTAssertEqual(syncPayload["verified"] as? Bool, false)

            let status = router.handle(RuntimeRequest(method: "GET", path: "/fr24/browser/status"))
            let statusPayload = try XCTUnwrap(
                JSONSerialization.jsonObject(with: status.body) as? [String: Any]
            )
            let managedBrowser = try XCTUnwrap(statusPayload["managed_browser"] as? [String: Any])
            XCTAssertEqual(managedBrowser["verification_opened"] as? Bool, true)

            let activePortText = try String(
                contentsOf: profileRoot.appendingPathComponent(".simnav-control-port"),
                encoding: .utf8
            )
            let browserPort = try XCTUnwrap(Int(activePortText.split(whereSeparator: { $0.isNewline })[0]))
            let targetsURL = try XCTUnwrap(URL(string: "http://localhost:\(browserPort)/json/list"))
            let targetsData = try Data(contentsOf: targetsURL)
            let targets = try XCTUnwrap(
                JSONSerialization.jsonObject(with: targetsData) as? [[String: Any]]
            )
            let pageURLs = targets.compactMap { target -> String? in
                guard target["type"] as? String == "page" else { return nil }
                return target["url"] as? String
            }
            XCTAssertTrue(pageURLs.contains { $0 == baseURL.absoluteString || $0 == baseURL.absoluteString + "/" })
            XCTAssertFalse(pageURLs.contains { $0.contains("/common/v1/airport.json") })
            XCTAssertFalse(pageURLs.contains("about:blank"))
            let homepageTitles = targets.compactMap { target -> String? in
                guard target["type"] as? String == "page",
                      let url = target["url"] as? String,
                      url == baseURL.absoluteString || url == baseURL.absoluteString + "/" else {
                    return nil
                }
                return target["title"] as? String
            }
            XCTAssertTrue(
                homepageTitles.contains("webdriver-false"),
                "The headed verification page must not expose Chromium's automation flag."
            )
        }
    }

    func testExternalChromiumEndpointUsesAuthenticatedControlAndPreservesHostProfile() async throws {
        let executable = [
            "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
            "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
            "/Applications/Chromium.app/Contents/MacOS/Chromium"
        ].first { FileManager.default.isExecutableFile(atPath: $0) }
        guard let executable else {
            throw XCTSkip("Chrome, Edge, or Chromium is not installed for the external CDP probe.")
        }

        let upstreamRouter = Router()
        upstreamRouter.get("/**") { request, _ -> Response in
            let isJSON = request.uri.path.hasSuffix("/common/v1/airport.json")
            var headers: HTTPFields = [:]
            headers[.contentType] = isJSON
                ? "application/json; charset=utf-8"
                : "text/html; charset=utf-8"
            let body = isJSON
                ? #"{"result":{"response":{"airport":{}}}}"#
                : "<html><head><title>External fixture</title></head><body>FR24 fixture ready</body></html>"
            return Response(
                status: .ok,
                headers: headers,
                body: .init(byteBuffer: ByteBuffer(string: body))
            )
        }
        let upstream = Application(router: upstreamRouter)

        try await upstream.test(.live) { client in
            let upstreamPort = try XCTUnwrap(client.port)
            let upstreamURL = try XCTUnwrap(URL(string: "http://localhost:\(upstreamPort)"))
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(
                "SimNavExternalCDPTests-\(UUID().uuidString)",
                isDirectory: true
            )
            defer { try? FileManager.default.removeItem(at: root) }
            let hostProfile = root.appendingPathComponent("HostFR24Browser", isDirectory: true)
            try FileManager.default.createDirectory(at: hostProfile, withIntermediateDirectories: true)
            let marker = hostProfile.appendingPathComponent("host-profile-marker")
            try Data("preserve".utf8).write(to: marker)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = [
                "--headless=new",
                "--remote-debugging-port=0",
                "--remote-debugging-address=127.0.0.1",
                "--user-data-dir=\(hostProfile.path)",
                "--no-first-run",
                "--no-default-browser-check",
                "--disable-sync",
                "--disable-background-mode",
                "--no-startup-window"
            ]
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            defer {
                if process.isRunning {
                    process.terminate()
                }
            }

            let activePortFile = hostProfile.appendingPathComponent("DevToolsActivePort")
            let deadline = Date().addingTimeInterval(15)
            var browserPort: Int?
            while Date() < deadline, browserPort == nil {
                if let text = try? String(contentsOf: activePortFile, encoding: .utf8),
                   let first = text.split(whereSeparator: { $0.isNewline }).first,
                   let port = Int(first) {
                    browserPort = port
                    break
                }
                if !process.isRunning {
                    break
                }
                try await Task.sleep(for: .milliseconds(100))
            }
            let endpoint = try XCTUnwrap(
                URL(string: "http://localhost:\(try XCTUnwrap(browserPort))")
            )
            let serverDataRoot = root.appendingPathComponent("ContainerData", isDirectory: true)
            let browser = LocalWebFR24BrowserFetch(configuration: .init(
                profileRoot: serverDataRoot.appendingPathComponent("FR24Browser", isDirectory: true),
                browserExecutableURL: nil,
                externalEndpointURL: endpoint,
                externalEndpointToken: "externalendpoint0123456789abcdef",
                apiBaseURL: upstreamURL,
                websiteBaseURL: upstreamURL
            ))
            let databaseURL = [
                workspaceRoot().appendingPathComponent("database/e_dfd_PMDG_release.s3db"),
                workspaceRoot().appendingPathComponent("NavPlanner/Resources/Database/navdata.sqlite")
            ].first { FileManager.default.fileExists(atPath: $0.path) }
            guard let databaseURL else {
                throw XCTSkip("Local ignored navigation database is not available.")
            }
            let router = SimNavRuntimeRouter(
                configuration: RuntimeConfiguration(
                    dataRoot: serverDataRoot,
                    bundledDatabaseURL: databaseURL
                ),
                fr24BrowserFetcher: browser
            )

            let opened = router.handle(RuntimeRequest(method: "POST", path: "/fr24/browser/open"))
            XCTAssertEqual(opened.status, 200, String(decoding: opened.body, as: UTF8.self))
            let synced = router.handle(RuntimeRequest(method: "POST", path: "/fr24/browser/sync"))
            XCTAssertEqual(synced.status, 200, String(decoding: synced.body, as: UTF8.self))
            let payload = try XCTUnwrap(
                JSONSerialization.jsonObject(with: synced.body) as? [String: Any]
            )
            XCTAssertEqual(payload["verified"] as? Bool, true)
            XCTAssertEqual(payload["access_method"] as? String, "managed_browser")

            try browser.clearBrowserSession()
            XCTAssertTrue(FileManager.default.fileExists(atPath: marker.path))
            XCTAssertFalse(FileManager.default.fileExists(
                atPath: serverDataRoot.appendingPathComponent("FR24Browser").path
            ))
        }
    }
#endif

    func testEveryHTTPAssetMatchesSharedResourceStoreBodyHashAndMIME() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.dataRoot) }
        let server = LocalWebHTTPServer(settings: fixture.settings)
        let app = Application(router: server.buildRouter())
        let enumerator = FileManager.default.enumerator(
            at: fixture.settings.webRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        var paths: [String] = []
        while let fileURL = enumerator?.nextObject() as? URL {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }
            paths.append(String(fileURL.path.dropFirst(fixture.settings.webRoot.path.count)))
        }
        XCTAssertFalse(paths.isEmpty)
        let assetPaths = paths.sorted()

        try await app.test(.router) { client in
            for path in assetPaths {
                let direct = server.webResourceStore.response(for: path)
                let response = try await client.execute(uri: path, method: .get)
                let body = Data(response.body.readableBytesView)
                let expectedBody: Data
                if path == "/map.html" {
                    let html = String(decoding: direct.body, as: UTF8.self)
                        .replacingOccurrences(of: "__SIMNAV_WRITE_TOKEN__", with: token)
                    expectedBody = Data(html.utf8)
                } else {
                    expectedBody = direct.body
                }
                XCTAssertEqual(response.status.code, direct.status, path)
                XCTAssertEqual(response.headers[.contentType], direct.contentType, path)
                XCTAssertEqual(bodyHash(body), bodyHash(expectedBody), path)
                XCTAssertEqual(body, expectedBody, path)

                let head = try await client.execute(uri: path, method: .head)
                XCTAssertEqual(head.status, response.status, path)
                XCTAssertEqual(head.headers[.contentType], response.headers[.contentType], path)
                XCTAssertEqual(Int(head.headers[.contentLength] ?? ""), expectedBody.count, path)
                XCTAssertEqual(head.body.readableBytes, 0, path)
            }
        }
    }

    func testOnlyRuntimeBridgeTouchesWebKit() throws {
        let webRoot = workspaceRoot().appendingPathComponent("NavPlanner/Resources/Web")
        let enumerator = FileManager.default.enumerator(
            at: webRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        var violations: [String] = []
        while let file = enumerator?.nextObject() as? URL {
            guard file.pathExtension == "js", file.lastPathComponent != "runtime.js" else { continue }
            guard let source = try? String(contentsOf: file, encoding: .utf8) else { continue }
            if source.contains("window.webkit") || source.contains("messageHandlers.navplanner") {
                violations.append(file.path)
            }
        }
        XCTAssertTrue(violations.isEmpty, "Direct WebKit bridge access outside runtime.js: \(violations)")
    }

    func testCanonicalWebSourceHasNoReplica() throws {
        let root = workspaceRoot()
        let canonicalIndex = root
            .appendingPathComponent("NavPlanner/Resources/Web/map.html")
            .standardizedFileURL
        let skippedDirectories = Set([
            ".build", ".git", "build", "codex", "database", "releases"
        ])
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        var replicas: [String] = []
        while let candidate = enumerator?.nextObject() as? URL {
            let values = try candidate.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true,
               skippedDirectories.contains(candidate.lastPathComponent) {
                enumerator?.skipDescendants()
                continue
            }
            if candidate.lastPathComponent == "map.html",
               candidate.standardizedFileURL != canonicalIndex {
                replicas.append(candidate.path)
            }
        }
        XCTAssertTrue(replicas.isEmpty, "Duplicate Web UI roots: \(replicas)")
    }

    func testFR24LaunchersDoNotExposeChromiumAutomationFlag() throws {
        let root = workspaceRoot()
        let nativeURL = root.appendingPathComponent(
            "LocalWeb/Sources/SimNavLocalWeb/LocalWebFR24BrowserFetch.swift"
        )
        let native = try String(contentsOf: nativeURL, encoding: .utf8)

        XCTAssertFalse(
            native.contains("--remote-debugging-port=0"),
            "The native adapter must use a non-zero loopback DevTools port so navigator.webdriver remains false."
        )
        XCTAssertTrue(native.contains("--remote-debugging-port=\\(browserPort)"))

        // The distributable launchers live above app/ in a packaged release, while
        // Linux package tests mount only app/ at /source. Check them here in a
        // source checkout; audit_web_release.sh checks the packaged copies.
        let trackedReleaseRoot = root.appendingPathComponent(
            "Tools/LocalWeb/release",
            isDirectory: true
        )
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(
            atPath: trackedReleaseRoot.path,
            isDirectory: &isDirectory
        ), isDirectory.boolValue {
            let launcherExpectations = [
                ("Linux", "run-linux.sh", "--remote-debugging-port=${browser_port}"),
                ("Windows", "run-windows.ps1", "--remote-debugging-port=$BrowserPort")
            ]
            for (name, fileName, expectedArgument) in launcherExpectations {
                let launcherURL = trackedReleaseRoot.appendingPathComponent(fileName)
                let source = try String(contentsOf: launcherURL, encoding: .utf8)
                XCTAssertFalse(
                    source.contains("--remote-debugging-port=0"),
                    "\(name) must use a non-zero loopback DevTools port so navigator.webdriver remains false."
                )
                XCTAssertTrue(source.contains(expectedArgument))
            }
        }
    }

    func testOriginTokenAndPathSecurity() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.dataRoot) }
        let server = LocalWebHTTPServer(settings: fixture.settings)
        let app = Application(router: server.buildRouter())

        try await app.test(.router) { client in
            var invalidOrigin: HTTPFields = [:]
            invalidOrigin[.origin] = "http://evil.example"
            let originResponse = try await client.execute(
                uri: "/api/header",
                method: .get,
                headers: invalidOrigin
            )
            XCTAssertEqual(originResponse.status, .forbidden)

            let rejectedWrite = try await client.execute(
                uri: "/api/procedure-preview/sid/BIAR",
                method: .post,
                body: ByteBuffer(string: "{\"procedures\":[]}")
            )
            XCTAssertEqual(rejectedWrite.status, .forbidden)

            let pathResponse = try await client.execute(
                uri: "/../Package.swift",
                method: .get
            )
            XCTAssertEqual(pathResponse.status, .forbidden)

            var uploadHeaders: HTTPFields = [:]
            uploadHeaders[try XCTUnwrap(HTTPField.Name("X-SimNav-Token"))] = token
            uploadHeaders[try XCTUnwrap(HTTPField.Name("X-SimNav-Filename"))] = "%2E%2E%5Cescape.s3db"
            let uploadTraversal = try await client.execute(
                uri: "/api/databases/import",
                method: .post,
                headers: uploadHeaders,
                body: ByteBuffer(string: "not-a-database")
            )
            XCTAssertEqual(uploadTraversal.status, .badRequest)
        }
    }

    func testOfflinePMTilesRangeAndCustomHeaders() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.dataRoot) }
        let offlineRoot = fixture.dataRoot.appendingPathComponent("MapOffline", isDirectory: true)
        try FileManager.default.createDirectory(at: offlineRoot, withIntermediateDirectories: true)
        let bytes = Data((0..<64).map(UInt8.init))
        try bytes.write(to: offlineRoot.appendingPathComponent("sample.pmtiles"))

        let server = LocalWebHTTPServer(settings: fixture.settings)
        let app = Application(router: server.buildRouter())
        try await app.test(.router) { client in
            let status = try await client.execute(uri: "/api/offline-maps", method: .get)
            XCTAssertEqual(status.status, .ok)
            XCTAssertTrue(String(decoding: status.body.readableBytesView, as: UTF8.self)
                .contains("sample"))

            var rangeHeaders: HTTPFields = [:]
            rangeHeaders[.range] = "bytes=4-11"
            let range = try await client.execute(
                uri: "/api/offline-maps/pmtiles/sample.pmtiles",
                method: .get,
                headers: rangeHeaders
            )
            XCTAssertEqual(range.status, .partialContent)
            XCTAssertEqual(range.headers[.acceptRanges], "bytes")
            XCTAssertEqual(range.headers[.contentRange], "bytes 4-11/64")
            XCTAssertEqual(Data(range.body.readableBytesView), bytes.subdata(in: 4..<12))

            let missingTile = try await client.execute(
                uri: "/api/offline-maps/tile/2/1/1.png",
                method: .get
            )
            XCTAssertEqual(missingTile.status, .ok)
            XCTAssertEqual(
                missingTile.headers.first { $0.name.rawName.lowercased() == "x-offline-map" }?.value,
                "MISS"
            )
            XCTAssertTrue(missingTile.headers[.accessControlExposeHeaders]?.contains("Content-Range") == true)

            var invalidRangeHeaders: HTTPFields = [:]
            invalidRangeHeaders[.range] = "bytes=64-80"
            let invalidRange = try await client.execute(
                uri: "/api/offline-maps/pmtiles/sample.pmtiles",
                method: .get,
                headers: invalidRangeHeaders
            )
            XCTAssertEqual(invalidRange.status.code, 416)
            XCTAssertEqual(invalidRange.headers[.acceptRanges], "bytes")
            XCTAssertEqual(invalidRange.headers[.contentRange], "bytes */64")
        }
    }

    func testPMTilesRangeTransportParityAcrossDirectWebKitAndHTTP() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.dataRoot) }
        let offlineRoot = fixture.dataRoot.appendingPathComponent("MapOffline", isDirectory: true)
        try FileManager.default.createDirectory(at: offlineRoot, withIntermediateDirectories: true)
        let bytes = Data((0..<64).map(UInt8.init))
        try bytes.write(to: offlineRoot.appendingPathComponent("transport.pmtiles"))

        let server = LocalWebHTTPServer(settings: fixture.settings)
        let app = Application(router: server.buildRouter())
        try await app.test(.router) { client in
            for expected in [
                (range: "bytes=4-11", status: 206, contentRange: "bytes 4-11/64"),
                (range: "bytes=64-80", status: 416, contentRange: "bytes */64")
            ] {
                let directRequest = RuntimeRequest(
                    method: "GET",
                    path: "/api/offline-maps/pmtiles/transport.pmtiles",
                    headers: ["Range": expected.range]
                )
                let direct = server.runtimeRouter.handle(directRequest)

                var urlRequest = URLRequest(
                    url: try XCTUnwrap(URL(string: "navplanner://api/offline-maps/pmtiles/transport.pmtiles"))
                )
                urlRequest.setValue(expected.range, forHTTPHeaderField: "Range")
                let webKitRuntime = server.runtimeRouter.handle(RuntimeRequest(urlRequest: urlRequest))
                let webKit = RuntimeWebKitResponseAdapter.adapt(
                    webKitRuntime,
                    baseHeaders: [
                        "Access-Control-Allow-Origin": "*",
                        "Access-Control-Expose-Headers": "Accept-Ranges, Content-Range"
                    ]
                )

                var httpHeaders: HTTPFields = [:]
                httpHeaders[.range] = expected.range
                let http = try await client.execute(
                    uri: "/api/offline-maps/pmtiles/transport.pmtiles",
                    method: .get,
                    headers: httpHeaders
                )
                let httpBody = Data(http.body.readableBytesView)

                XCTAssertEqual(direct.status, expected.status)
                XCTAssertEqual(webKit.statusCode, direct.status)
                XCTAssertEqual(http.status.code, direct.status)
                XCTAssertEqual(webKit.mimeType, direct.contentType)
                XCTAssertEqual(http.headers[.contentType], direct.contentType)
                XCTAssertEqual(webKit.headers["Accept-Ranges"], "bytes")
                XCTAssertEqual(http.headers[.acceptRanges], "bytes")
                XCTAssertEqual(webKit.headers["Content-Range"], expected.contentRange)
                XCTAssertEqual(http.headers[.contentRange], expected.contentRange)
                XCTAssertEqual(webKit.data, direct.body)
                XCTAssertEqual(httpBody, direct.body)
                XCTAssertEqual(bodyHash(webKit.data), bodyHash(httpBody))
                XCTAssertEqual(webKit.headers["Access-Control-Allow-Origin"], "*")
                XCTAssertTrue(http.headers[.accessControlExposeHeaders]?.contains("Content-Range") == true)
            }
        }
    }

    func testOfflineMapUploadStreamsIntoSharedMapStore() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.dataRoot) }
        let sourceURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "SimNavMapUpload-\(UUID().uuidString).mbtiles"
        )
        defer { try? FileManager.default.removeItem(at: sourceURL) }
        try makeMBTilesFixture(at: sourceURL)
        let sourceData = try Data(contentsOf: sourceURL)

        let server = LocalWebHTTPServer(settings: fixture.settings)
        let app = Application(router: server.buildRouter())
        try await app.test(.router) { client in
            var headers: HTTPFields = [:]
            headers[.contentType] = "application/octet-stream"
            headers[try XCTUnwrap(HTTPField.Name("X-SimNav-Token"))] = token
            headers[try XCTUnwrap(HTTPField.Name("X-SimNav-Filename"))] = "city.mbtiles"
            let response = try await client.execute(
                uri: "/api/offline-maps/import",
                method: .post,
                headers: headers,
                body: ByteBuffer(bytes: sourceData)
            )
            XCTAssertEqual(response.status, .ok)
            let payload = try XCTUnwrap(
                JSONSerialization.jsonObject(with: Data(response.body.readableBytesView)) as? [String: Any]
            )
            XCTAssertEqual(payload["active"] as? String, "fixture-city")
            XCTAssertEqual((payload["imported"] as? [String: Any])?["name"] as? String, "fixture-city")
            let resources = try XCTUnwrap(payload["resources"] as? [[String: Any]])
            XCTAssertTrue(resources.contains { $0["name"] as? String == "fixture-city" })

            let status = try await client.execute(uri: "/api/offline-maps", method: .get)
            XCTAssertEqual(status.status, .ok)
            XCTAssertTrue(String(decoding: status.body.readableBytesView, as: UTF8.self)
                .contains("fixture-city"))

            let options = try await client.execute(
                uri: "/api/offline-maps/import",
                method: .options,
                headers: {
                    var fields: HTTPFields = [:]
                    fields[.origin] = "http://127.0.0.1:8010"
                    return fields
                }()
            )
            XCTAssertEqual(options.status, .noContent)
            XCTAssertTrue(options.headers[.accessControlAllowHeaders]?.contains("X-SimNav-Filename") == true)
        }
    }

    func testDatabaseUploadStreamsPastGenericBodyLimitAndActivatesDatabase() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.dataRoot) }
        let sourceURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "SimNavDatabaseUpload-\(UUID().uuidString).s3db"
        )
        defer { try? FileManager.default.removeItem(at: sourceURL) }
        try makeNavigationDatabaseFixture(at: sourceURL, paddingBytes: 5 * 1_024 * 1_024)
        let sourceData = try Data(contentsOf: sourceURL)
        XCTAssertGreaterThan(sourceData.count, 4 * 1_024 * 1_024)

        let server = LocalWebHTTPServer(settings: fixture.settings)
        let app = Application(router: server.buildRouter())
        try await app.test(.router) { client in
            var headers: HTTPFields = [:]
            headers[.contentType] = "application/octet-stream"
            headers[try XCTUnwrap(HTTPField.Name("X-SimNav-Token"))] = token
            headers[try XCTUnwrap(HTTPField.Name("X-SimNav-Filename"))] = "navcycle.s3db"
            let response = try await client.execute(
                uri: "/api/databases/import",
                method: .post,
                headers: headers,
                body: ByteBuffer(bytes: sourceData)
            )
            XCTAssertEqual(response.status, .ok)
            let payload = try XCTUnwrap(
                JSONSerialization.jsonObject(with: Data(response.body.readableBytesView)) as? [String: Any]
            )
            XCTAssertEqual(payload["local_status"] as? String, "ready")
            XCTAssertEqual(payload["database_name"] as? String, "navcycle.sqlite")

            let header = try await client.execute(uri: "/api/header", method: .get)
            XCTAssertEqual(header.status, .ok)
            let headerPayload = try XCTUnwrap(
                JSONSerialization.jsonObject(with: Data(header.body.readableBytesView)) as? [String: Any]
            )
            XCTAssertEqual(headerPayload["current_airac"] as? String, "9999")
            XCTAssertEqual(headerPayload["revision"] as? String, "fixture")
        }

        let restartedServer = LocalWebHTTPServer(settings: fixture.settings)
        let restartedApp = Application(router: restartedServer.buildRouter())
        try await restartedApp.test(.router) { client in
            let header = try await client.execute(uri: "/api/header", method: .get)
            XCTAssertEqual(header.status, .ok)
            let headerPayload = try XCTUnwrap(
                JSONSerialization.jsonObject(with: Data(header.body.readableBytesView)) as? [String: Any]
            )
            XCTAssertEqual(headerPayload["current_airac"] as? String, "9999")
            XCTAssertEqual(headerPayload["revision"] as? String, "fixture")

            let databases = try await client.execute(uri: "/api/databases/list", method: .get)
            XCTAssertEqual(databases.status, .ok)
            let databasePayload = try XCTUnwrap(
                JSONSerialization.jsonObject(with: Data(databases.body.readableBytesView)) as? [String: Any]
            )
            let items = try XCTUnwrap(databasePayload["items"] as? [[String: Any]])
            XCTAssertTrue(items.contains {
                $0["name"] as? String == "navcycle.sqlite" && $0["active"] as? Bool == true
            })
        }
    }

    func testUnsafeActiveDatabaseMarkerFallsBackInsideDataRoot() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.dataRoot) }
        let sourceURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "SimNavBundledDatabase-\(UUID().uuidString).s3db"
        )
        defer { try? FileManager.default.removeItem(at: sourceURL) }
        try makeNavigationDatabaseFixture(at: sourceURL, paddingBytes: 0)

        let databaseDirectory = fixture.dataRoot.appendingPathComponent("Database", isDirectory: true)
        try FileManager.default.createDirectory(at: databaseDirectory, withIntermediateDirectories: true)
        try Data("..\\outside.s3db\n".utf8).write(
            to: databaseDirectory.appendingPathComponent(".active-database")
        )
        let settings = LocalWebSettings(
            port: fixture.settings.port,
            bindHost: fixture.settings.bindHost,
            webRoot: fixture.settings.webRoot,
            dataRoot: fixture.dataRoot,
            bundledDatabaseURL: sourceURL,
            writeToken: token
        )
        let server = LocalWebHTTPServer(settings: settings)
        let app = Application(router: server.buildRouter())
        try await app.test(.router) { client in
            let header = try await client.execute(uri: "/api/header", method: .get)
            XCTAssertEqual(header.status, .ok)
            let payload = try XCTUnwrap(
                JSONSerialization.jsonObject(with: Data(header.body.readableBytesView)) as? [String: Any]
            )
            XCTAssertEqual(payload["current_airac"] as? String, "9999")
            XCTAssertEqual(payload["database_name"] as? String, "navdata.sqlite")
        }

        let marker = try String(
            contentsOf: databaseDirectory.appendingPathComponent(".active-database"),
            encoding: .utf8
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(marker, "navdata.sqlite")
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: fixture.dataRoot.deletingLastPathComponent().appendingPathComponent("outside.s3db").path
        ))
    }

    private func makeFixture() throws -> (settings: LocalWebSettings, dataRoot: URL) {
        let webRoot = workspaceRoot().appendingPathComponent(
            "NavPlanner/Resources/Web",
            isDirectory: true
        )
        let dataRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
            "SimNavLocalWebTests-\(UUID().uuidString)",
            isDirectory: true
        )
        return (
            LocalWebSettings(
                port: 8010,
                bindHost: "127.0.0.1",
                webRoot: webRoot,
                dataRoot: dataRoot,
                bundledDatabaseURL: nil,
                writeToken: token
            ),
            dataRoot
        )
    }

    private func workspaceRoot() -> URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 {
            root.deleteLastPathComponent()
        }
        return root
    }

    private func bodyHash(_ data: Data) -> String {
        let value = data.reduce(UInt64(0xcbf29ce484222325)) { partial, byte in
            (partial ^ UInt64(byte)) &* 0x100000001b3
        }
        return String(format: "%016llx", value)
    }

    private func makeMBTilesFixture(at url: URL) throws {
        var database: OpaquePointer?
        guard sqlite3_open(url.path, &database) == SQLITE_OK, let database else {
            throw NSError(domain: "SimNavLocalWebTests", code: 1)
        }
        defer { sqlite3_close(database) }
        let sql = """
        CREATE TABLE metadata (name TEXT, value TEXT);
        INSERT INTO metadata (name, value) VALUES
            ('name', 'fixture-city'),
            ('format', 'png'),
            ('minzoom', '0'),
            ('maxzoom', '0'),
            ('bounds', '-180,-85,180,85');
        CREATE TABLE tiles (
            zoom_level INTEGER,
            tile_column INTEGER,
            tile_row INTEGER,
            tile_data BLOB
        );
        INSERT INTO tiles VALUES (0, 0, 0, X'89504E470D0A1A0A');
        """
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw NSError(
                domain: "SimNavLocalWebTests",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(database))]
            )
        }
    }

    private func makeNavigationDatabaseFixture(at url: URL, paddingBytes: Int) throws {
        var database: OpaquePointer?
        guard sqlite3_open(url.path, &database) == SQLITE_OK, let database else {
            throw NSError(domain: "SimNavLocalWebTests", code: 3)
        }
        defer { sqlite3_close(database) }
        let sql = """
        CREATE TABLE tbl_header (current_airac TEXT, revision TEXT);
        INSERT INTO tbl_header VALUES ('9999', 'fixture');
        CREATE TABLE tbl_airports (airport_identifier TEXT);
        CREATE TABLE tbl_runways (airport_identifier TEXT);
        CREATE TABLE tbl_enroute_waypoints (waypoint_identifier TEXT);
        CREATE TABLE tbl_enroute_airways (route_identifier TEXT);
        CREATE TABLE fixture_padding (payload BLOB);
        INSERT INTO fixture_padding VALUES (zeroblob(\(paddingBytes)));
        """
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw NSError(
                domain: "SimNavLocalWebTests",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(database))]
            )
        }
    }
}

private final class HTTPManagedBrowserFR24Fixture: FR24BrowserFetching, FR24BrowserSessionManaging {
    private(set) var openCount = 0
    private(set) var requestCount = 0

    func openVerificationPage() throws -> [String: Any] {
        openCount += 1
        return [
            "opened": true,
            "access_method": "managed_browser",
            "isolated_profile": true
        ]
    }

    func browserSessionStatusPayload() -> [String: Any] {
        [
            "available": true,
            "running": openCount > 0,
            "isolated_profile": true,
            "browser": "Fixture Chromium",
            "verification_opened": openCount > 0
        ]
    }

    func clearBrowserSession() throws {
        openCount = 0
    }

    func performJSONRequest(path: String, params: [(String, String)]) throws -> [String: Any] {
        requestCount += 1
        return ["result": [String: Any]()]
    }

    func performFlightHistoryPageRequest(flightToken: String) throws -> [String: Any] {
        ["rows": [[String: Any]]()]
    }
}

private enum CDPFR24Fixture {
    static let scheduleJSON = #"""
    {
      "result": {"response": {"airport": {"pluginData": {"schedule": {"departures": {"data": [
        {"flight": {
          "identification": {"id": "40fc18c8", "number": {"default": "CA4123"}, "callsign": "CCA4123"},
          "airline": {"name": "Air China"},
          "aircraft": {"model": {"code": "A359"}, "registration": "B-32NH"},
          "airport": {
            "origin": {"code": {"icao": "ZBAA", "iata": "PEK"}, "name": "Beijing Capital"},
            "destination": {"code": {"icao": "ZULS", "iata": "LXA"}, "name": "Lhasa Gonggar"}
          },
          "time": {"scheduled": {"departure": 1786580000, "arrival": 1786591700}, "real": {"departure": 1786580000, "arrival": 1786591700}},
          "status": {"text": "Landed"}
        }}
      ]}}}}}}
    }
    """#

    static let playbackJSON = #"""
    {
      "track": [
        {"lat":40.07333333,"lon":116.59833333,"altitude":1000,"speed":180,"timestamp":1786580000},
        {"lat":38.75888889,"lon":114.97777778,"altitude":3200,"speed":210,"timestamp":1786580900},
        {"lat":38.31638889,"lon":113.81555556,"altitude":6400,"speed":240,"timestamp":1786581800},
        {"lat":37.32694444,"lon":111.73750000,"altitude":9600,"speed":270,"timestamp":1786582700},
        {"lat":34.50472222,"lon":108.55166667,"altitude":12800,"speed":300,"timestamp":1786583600},
        {"lat":33.41388889,"lon":108.08805556,"altitude":16000,"speed":330,"timestamp":1786584500},
        {"lat":32.30527778,"lon":106.67444444,"altitude":19200,"speed":360,"timestamp":1786585400},
        {"lat":31.04805556,"lon":104.66722222,"altitude":22400,"speed":390,"timestamp":1786586300},
        {"lat":30.64500000,"lon":103.68666667,"altitude":25600,"speed":420,"timestamp":1786587200},
        {"lat":30.78277778,"lon":101.90277778,"altitude":28800,"speed":420,"timestamp":1786588100},
        {"lat":31.14666667,"lon":97.17666667,"altitude":32000,"speed":420,"timestamp":1786589000},
        {"lat":30.51083333,"lon":94.19805556,"altitude":35000,"speed":420,"timestamp":1786589900},
        {"lat":29.82888889,"lon":91.82222222,"altitude":35000,"speed":420,"timestamp":1786590800},
        {"lat":29.29666667,"lon":90.91166667,"altitude":35000,"speed":420,"timestamp":1786591700}
      ]
    }
    """#
}
#endif
