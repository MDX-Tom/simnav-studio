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
}
