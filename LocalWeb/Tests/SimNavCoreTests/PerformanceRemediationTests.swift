import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import SimNavCore

final class PerformanceRemediationTests: XCTestCase {
    func testVendorSourceMappingReferencesResolveInsideCanonicalWebRoot() throws {
        let webRoot = workspaceRoot().appendingPathComponent("NavPlanner/Resources/Web", isDirectory: true)
        let enumerator = try XCTUnwrap(
            FileManager.default.enumerator(
                at: webRoot,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        )
        let pattern = try NSRegularExpression(pattern: #"sourceMappingURL=([^\s*]+)"#)
        var missing: [String] = []
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "js" {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            let sourceRange = NSRange(source.startIndex..., in: source)
            for match in pattern.matches(in: source, range: sourceRange) {
                guard let range = Range(match.range(at: 1), in: source) else { continue }
                let reference = String(source[range])
                guard !reference.hasPrefix("data:") else { continue }
                let target = fileURL.deletingLastPathComponent().appendingPathComponent(reference)
                if !FileManager.default.fileExists(atPath: target.path) {
                    missing.append("\(fileURL.path.replacingOccurrences(of: webRoot.path + "/", with: "")) -> \(reference)")
                }
            }
        }
        XCTAssertTrue(missing.isEmpty, "Missing vendor source maps: \(missing.sorted())")
    }

    func testWeatherIdenticalColdRequestsUseSingleFlightAndWarmCache() throws {
        PerformanceWeatherURLProtocol.reset()
        XCTAssertTrue(URLProtocol.registerClass(PerformanceWeatherURLProtocol.self))
        defer { URLProtocol.unregisterClass(PerformanceWeatherURLProtocol.self) }

        let proxy = SimNavWeatherProxy()
        let request = RuntimeRequest(
            method: "GET",
            path: "/weather/open-meteo",
            query: [
                "latitude": ["40.1,39.2"],
                "longitude": ["116.6,91.1"],
                "hourly": ["temperature_2m,wind_speed_250hPa"],
                "models": ["ecmwf_ifs025"],
                "timezone": ["GMT"]
            ]
        )
        let responses = PerformanceResponseCollector()
        let group = DispatchGroup()
        let queue = DispatchQueue(
            label: "com.mdxtom.simnavstudio.tests.weather-single-flight",
            attributes: .concurrent
        )
        for _ in 0..<5 {
            group.enter()
            queue.async {
                let response = proxy.response(for: request)
                responses.append(response)
                group.leave()
            }
        }
        XCTAssertEqual(group.wait(timeout: .now() + 4), .success)
        let responseSnapshot = responses.snapshot
        XCTAssertEqual(responseSnapshot.count, 5)
        XCTAssertTrue(responseSnapshot.allSatisfy { $0.status == 200 })
        XCTAssertEqual(PerformanceWeatherURLProtocol.requestCount, 1)

        let warmStarted = DispatchTime.now().uptimeNanoseconds
        let warm = proxy.response(for: request)
        let warmMilliseconds = Double(DispatchTime.now().uptimeNanoseconds - warmStarted) / 1_000_000
        XCTAssertEqual(warm.status, 200)
        XCTAssertEqual(warm.headers["X-Weather-Cache"], "HIT")
        XCTAssertEqual(PerformanceWeatherURLProtocol.requestCount, 1)
        XCTAssertLessThan(warmMilliseconds, 100)
    }

    func testWeatherTTLRefreshStaleFallbackAndCanonicalKeyIsolation() throws {
        PerformanceWeatherURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PerformanceWeatherURLProtocol.self]
        let clock = PerformanceMutableClock(Date(timeIntervalSince1970: 1_786_000_000))
        let proxy = SimNavWeatherProxy(
            session: URLSession(configuration: configuration),
            freshTTL: 1,
            staleTTL: 20,
            requestTimeout: 1,
            waitTimeout: 2,
            now: { clock.value }
        )
        let request = weatherRequest(
            hourly: ["wind_speed_250hPa", "temperature_2m"],
            model: "ecmwf_ifs025"
        )
        PerformanceWeatherURLProtocol.configure(statusCode: 200, bodyMarker: "v1", delay: 0.01)
        let cold = proxy.response(for: request)
        XCTAssertEqual(cold.status, 200)
        XCTAssertEqual(cold.headers["X-Weather-Cache"], "MISS")
        XCTAssertTrue(String(decoding: cold.body, as: UTF8.self).contains("v1"))
        XCTAssertEqual(PerformanceWeatherURLProtocol.requestCount, 1)

        let reordered = weatherRequest(
            hourly: ["temperature_2m", "wind_speed_250hPa"],
            model: "ecmwf_ifs025"
        )
        let fresh = proxy.response(for: reordered)
        XCTAssertEqual(fresh.headers["X-Weather-Cache"], "HIT")
        XCTAssertEqual(PerformanceWeatherURLProtocol.requestCount, 1)

        clock.advance(by: 2)
        PerformanceWeatherURLProtocol.configure(statusCode: 200, bodyMarker: "v2", delay: 0.01)
        let refreshed = proxy.response(for: request)
        XCTAssertEqual(refreshed.headers["X-Weather-Cache"], "MISS")
        XCTAssertTrue(String(decoding: refreshed.body, as: UTF8.self).contains("v2"))
        XCTAssertEqual(PerformanceWeatherURLProtocol.requestCount, 2)

        clock.advance(by: 2)
        PerformanceWeatherURLProtocol.configure(statusCode: 503, bodyMarker: "upstream-down", delay: 0.01)
        let stale = proxy.response(for: request)
        XCTAssertEqual(stale.status, 200)
        XCTAssertEqual(stale.headers["X-Weather-Cache"], "STALE")
        XCTAssertNotNil(stale.headers["X-Weather-Stale-Reason"])
        XCTAssertTrue(String(decoding: stale.body, as: UTF8.self).contains("v2"))
        XCTAssertEqual(PerformanceWeatherURLProtocol.requestCount, 3)

        let isolatedModel = proxy.response(for: weatherRequest(
            hourly: ["temperature_2m", "wind_speed_250hPa"],
            model: "gfs_seamless"
        ))
        XCTAssertEqual(isolatedModel.status, 503)
        XCTAssertEqual(PerformanceWeatherURLProtocol.requestCount, 4)
    }

    func testWeatherWebKitAndHTTPRequestsUseSameRouterBodyAndMIME() throws {
        PerformanceWeatherURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PerformanceWeatherURLProtocol.self]
        PerformanceWeatherURLProtocol.configure(statusCode: 200, bodyMarker: "transport", delay: 0)
        let proxy = SimNavWeatherProxy(session: URLSession(configuration: configuration))
        let unavailableDatabase = FileManager.default.temporaryDirectory
            .appendingPathComponent("SimNavWeatherTransport-\(UUID().uuidString).sqlite")
        let router = SimNavRuntimeRouter(
            plannerService: PlannerService(dataStore: LocalDataStore(databaseURL: unavailableDatabase)),
            weatherProxy: proxy
        )
        let target = "/api/weather/open-meteo?latitude=40.1&longitude=116.6&hourly=temperature_2m&models=ecmwf_ifs025"
        let webKitURL = try XCTUnwrap(URL(string: "navplanner://api\(target.dropFirst(4))"))
        let webKit = router.handle(RuntimeRequest(urlRequest: URLRequest(url: webKitURL)))
        let http = router.handle(RuntimeRequest(httpMethod: "GET", httpTarget: target))
        XCTAssertEqual(webKit.status, 200)
        XCTAssertEqual(http.status, 200)
        XCTAssertEqual(webKit.contentType, http.contentType)
        XCTAssertEqual(webKit.body, http.body)
        XCTAssertEqual(PerformanceWeatherURLProtocol.requestCount, 1)
    }

    func testCalculateWeatherCancelsSupersededFetchAndPreservesLastProfile() throws {
        let source = try String(
            contentsOf: workspaceRoot().appendingPathComponent(
                "NavPlanner/Resources/Web/pages/calculate.js"
            ),
            encoding: .utf8
        )
        XCTAssertTrue(source.contains("state.calculateOnlineWeatherController?.abort()"))
        XCTAssertTrue(source.contains("signal: controller.signal"))
        XCTAssertTrue(source.contains(#"error?.name === "AbortError""#))
        let ensureStart = try XCTUnwrap(source.range(of: "function ensureCalculateOnlineWeather(route)"))
        let ensureTail = source[ensureStart.lowerBound...]
        let ensureEnd = try XCTUnwrap(ensureTail.range(of: "function onlineWeatherPointForDistance"))
        let ensureBody = ensureTail[..<ensureEnd.lowerBound]
        XCTAssertFalse(ensureBody.contains("state.calculateOnlineWeather = null"))
    }

    func testOnlineTileRouterDoesNotSynchronouslyWaitForQueuedDownload() throws {
        let routerSource = try String(
            contentsOf: workspaceRoot().appendingPathComponent(
                "NavPlanner/Core/Runtime/SimNavRuntimeRouter.swift"
            ),
            encoding: .utf8
        )
        let functionStart = try XCTUnwrap(routerSource.range(of: "private func onlineTileResponse("))
        let functionTail = routerSource[functionStart.lowerBound...]
        let functionEnd = try XCTUnwrap(functionTail.range(of: "private func onlineTileHitResponse("))
        let functionBody = functionTail[..<functionEnd.lowerBound]
        XCTAssertFalse(
            functionBody.contains("waitForDownload: SimNavOnlineTileCache.tileResponseWaitTimeout"),
            "Queued tile requests must return immediately while the shared cache job continues in background."
        )
    }

    func testOnlineTileColdMissReturnsQuicklyAndSharedJobEventuallyHits() throws {
        PerformanceTileURLProtocol.reset(delay: 0.35)
        let fixture = makeTileRouterFixture()
        defer {
            _ = fixture.cache.clearPayload()
            try? FileManager.default.removeItem(at: fixture.root)
        }
        let request = RuntimeRequest(method: "GET", path: "/terrain/terrarium/10/1/1.png")
        let start = DispatchTime.now().uptimeNanoseconds
        let queued = fixture.router.handle(request)
        let elapsedMilliseconds = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
        XCTAssertEqual(queued.status, 200)
        XCTAssertTrue(["QUEUED", "PENDING"].contains(queued.headers["X-Map-Cache"] ?? ""))
        XCTAssertEqual(queued.headers["X-Map-Retry-After-Ms"], "350")
        XCTAssertLessThan(elapsedMilliseconds, 100)

        for _ in 0..<5 {
            let coalesced = fixture.router.handle(request)
            XCTAssertTrue(["QUEUED", "PENDING"].contains(coalesced.headers["X-Map-Cache"] ?? ""))
        }
        let hit = try waitForTileHit(router: fixture.router, request: request, timeout: 2)
        XCTAssertEqual(hit.headers["X-Map-Cache"], "HIT")
        XCTAssertEqual(hit.body, PerformanceTileURLProtocol.tileData)
        XCTAssertEqual(PerformanceTileURLProtocol.requestCount, 1)
        let status = fixture.cache.statusPayload()
        XCTAssertEqual(status["queue_capacity"] as? Int, 120)
        XCTAssertEqual(status["failed_count"] as? Int, 0)
        XCTAssertEqual(status["successful_download_count"] as? Int, 1)
    }

    func testOnlineTileDemandGenerationCancelsStaleJobAndParentFallbackRemainsVisible() throws {
        PerformanceTileURLProtocol.reset(delay: 0.45)
        let fixture = makeTileRouterFixture()
        defer {
            _ = fixture.cache.clearPayload()
            try? FileManager.default.removeItem(at: fixture.root)
        }
        XCTAssertGreaterThan(
            SimNavOnlineTileCache.RequestPriority.visible.rawValue,
            SimNavOnlineTileCache.RequestPriority.preview.rawValue
        )

        let stale = RuntimeRequest(
            method: "GET",
            path: "/terrain/terrarium/10/7/7.png/demand/1"
        )
        let current = RuntimeRequest(
            method: "GET",
            path: "/terrain/terrarium/10/8/8.png/demand/2"
        )
        _ = fixture.router.handle(stale)
        Thread.sleep(forTimeInterval: 0.05)
        _ = fixture.router.handle(current)
        let currentHit = try waitForTileHit(router: fixture.router, request: current, timeout: 2)
        XCTAssertEqual(currentHit.headers["X-Map-Cache"], "HIT")
        let generationStatus = fixture.cache.statusPayload()
        XCTAssertGreaterThanOrEqual(generationStatus["cancelled_stale_count"] as? Int ?? 0, 1)
        XCTAssertEqual(generationStatus["failed_count"] as? Int, 0)

        PerformanceTileURLProtocol.configure(delay: 0)
        let parent = RuntimeRequest(method: "GET", path: "/map-cache/openstreetmap/9/1/1.png")
        _ = fixture.router.handle(parent)
        let parentHit = try waitForTileHit(router: fixture.router, request: parent, timeout: 1)
        XCTAssertEqual(parentHit.headers["X-Map-Cache"], "HIT")
        PerformanceTileURLProtocol.configure(delay: 0.35)
        let child = fixture.router.handle(RuntimeRequest(
            method: "GET",
            path: "/map-cache/openstreetmap/10/2/2.png"
        ))
        XCTAssertEqual(child.headers["X-Map-Cache"], "FALLBACK")
        XCTAssertEqual(child.headers["X-Map-Fallback-Zoom"], "9")
        XCTAssertEqual(child.headers["X-Map-Retry-After-Ms"], "350")
        XCTAssertEqual(child.body, parentHit.body)
    }

    func testTerrainSchedulerIsGenerationAwareDeduplicatedAndBounded() throws {
        let source = try String(
            contentsOf: workspaceRoot().appendingPathComponent(
                "NavPlanner/Resources/Web/pages/calculate.js"
            ),
            encoding: .utf8
        )
        XCTAssertTrue(source.contains("const CALC_TERRAIN_MAX_CONCURRENT = 4"))
        XCTAssertTrue(source.contains("calculateTerrainJobs.get(key)"))
        XCTAssertTrue(source.contains("job.controller.abort()"))
        XCTAssertTrue(source.contains("job.generation !== state.calculateTerrainGeneration"))
        XCTAssertTrue(source.contains("terrainRetryHeaderMilliseconds(response)"))
        XCTAssertTrue(source.contains("while (calculateTerrainActiveCount < CALC_TERRAIN_MAX_CONCURRENT"))
    }

    func testNavOverlayBuildIsFrameBudgetedGenerationAwareAndAtomic() throws {
        let source = try String(
            contentsOf: workspaceRoot().appendingPathComponent(
                "NavPlanner/Resources/Web/app.js"
            ),
            encoding: .utf8
        )
        XCTAssertTrue(source.contains("const NAV_OVERLAY_FRAME_BUDGET_MS = 7"))
        XCTAssertTrue(source.contains("async function buildNavOverlayChunked"))
        XCTAssertTrue(source.contains("window.requestAnimationFrame(resolve)"))
        XCTAssertTrue(source.contains("drawVersion !== state.navOverlayDrawVersion"))
        XCTAssertTrue(source.contains("let navOverlayDrawChain = Promise.resolve()"))
        XCTAssertTrue(source.contains("state.navOverlayDrawPayload === payload"))
        XCTAssertTrue(source.contains("const drawn = await drawNavOverlay"))
        XCTAssertTrue(source.contains("previousNavAirwayLayerGroup"))
        XCTAssertTrue(source.contains("applyMapOverlayVisibility();"))
        XCTAssertTrue(source.contains("state.navOverlayBuildMetrics = {"))
        XCTAssertTrue(source.contains("batchedAirwayPaths.push(rawAirwayPath.map"))
        XCTAssertTrue(source.contains("state.navAirwayPaths.set(airway.name"))
        XCTAssertTrue(source.contains("nearestAirwayForLatLng(event.latlng, batchedAirwayCandidates)"))
        XCTAssertTrue(source.contains("highlightLayer._plannerNavAirwayHighlight = true"))
        XCTAssertTrue(source.contains("window.navplannerPerformanceProbe = Object.freeze"))
        XCTAssertTrue(source.contains("runWorkflowStress: (options = {})"))

        let builderStart = try XCTUnwrap(source.range(of: "async function buildNavOverlay(payload, drawVersion)"))
        let builderTail = source[builderStart.lowerBound...]
        let builderEnd = try XCTUnwrap(builderTail.range(of: "function scheduleNavOverlayRetry"))
        let builder = builderTail[..<builderEnd.lowerBound]
        for phase in ["indexes", "airways", "runways_ils", "airports", "navaids", "waypoints_labels", "swap"] {
            XCTAssertTrue(builder.contains("runPhase(\"\(phase)\""), "Missing timing phase \(phase)")
        }
        let swapRange = try XCTUnwrap(builder.range(of: "await runPhase(\"swap\""))
        let swapTail = builder[swapRange.lowerBound...]
        XCTAssertTrue(swapTail.contains("removeNavOverlayLayerAfterPaint"))
    }

    func testCapturedTrackMatchesPreserveBaselineAndWarmResponseIsMemoized() throws {
        let root = workspaceRoot()
        let databaseURL = try XCTUnwrap(
            [
                root.appendingPathComponent("database/e_dfd_PMDG_release.s3db"),
                root.appendingPathComponent("NavPlanner/Resources/Database/navdata.sqlite")
            ].first { FileManager.default.fileExists(atPath: $0.path) },
            "A release-selected navigation database is required for captured track regression."
        )
        let fixtureRoot = try XCTUnwrap(Bundle.module.resourceURL)
            .appendingPathComponent("Fixtures", isDirectory: true)
        let trackRoot = fixtureRoot.appendingPathComponent("CapturedTracks", isDirectory: true)
        let baselineRoot = fixtureRoot.appendingPathComponent("ExpectedTrackMatches", isDirectory: true)
        let service = PlannerService(dataStore: LocalDataStore(databaseURL: databaseURL))
        var timingRecords: [[String: Any]] = []

        for id in ["4143095e", "4142d706", "4141e167", "41420e18"] {
            let object = try XCTUnwrap(
                JSONSerialization.jsonObject(
                    with: Data(contentsOf: trackRoot.appendingPathComponent("\(id).json"))
                ) as? [String: Any]
            )
            XCTAssertEqual(
                Set(object.keys),
                Set(["departure", "arrival", "track_points"]),
                "Captured track fixtures must contain only fields consumed by this regression."
            )
            let points = try XCTUnwrap(object["track_points"] as? [[String: Any]])
            XCTAssertTrue(
                points.allSatisfy { Set($0.keys) == Set(["lat", "lon"]) },
                "Captured track points must contain only latitude and longitude."
            )
            let departure = try XCTUnwrap(object["departure"] as? String)
            let arrival = try XCTUnwrap(object["arrival"] as? String)

            let coldStartedAt = DispatchTime.now().uptimeNanoseconds
            let cold = service.trackMatchPayload(
                departure: departure,
                arrival: arrival,
                trackPoints: points
            )
            let coldMilliseconds = Double(
                DispatchTime.now().uptimeNanoseconds - coldStartedAt
            ) / 1_000_000
            let expectedData = try Data(
                contentsOf: baselineRoot.appendingPathComponent("\(id).cold.json")
            )
            let expected = try XCTUnwrap(
                JSONSerialization.jsonObject(
                    with: expectedData
                ) as? [String: Any]
            )
            #if os(macOS)
            let canonicalExpectedData = try JSONSerialization.data(
                withJSONObject: expected,
                options: [.prettyPrinted, .sortedKeys]
            )
            let coldData = try JSONSerialization.data(
                withJSONObject: cold,
                options: [.prettyPrinted, .sortedKeys]
            )
            XCTAssertEqual(coldData, canonicalExpectedData, "Track-match payload changed for \(id)")
            #endif
            XCTAssertNil(
                jsonMismatch(actual: cold, expected: expected),
                "Track-match payload changed for \(id)"
            )

            let phasePayload = service.lastTrackMatchPerformancePayload()
            XCTAssertEqual(phasePayload["cache_hit"] as? Bool, false)
            XCTAssertNotNil((phasePayload["phases_ms"] as? [String: Double])?["snap"])
            XCTAssertLessThan(coldMilliseconds, id == "4143095e" ? 6_500 : 3_500)

            let warmStartedAt = DispatchTime.now().uptimeNanoseconds
            let warm = service.trackMatchPayload(
                departure: departure,
                arrival: arrival,
                trackPoints: points
            )
            let warmMilliseconds = Double(
                DispatchTime.now().uptimeNanoseconds - warmStartedAt
            ) / 1_000_000
            #if os(macOS)
            let warmData = try JSONSerialization.data(
                withJSONObject: warm,
                options: [.prettyPrinted, .sortedKeys]
            )
            XCTAssertEqual(warmData, canonicalExpectedData)
            #endif
            XCTAssertNil(jsonMismatch(actual: warm, expected: expected))
            XCTAssertLessThan(warmMilliseconds, 200)
            XCTAssertEqual(service.lastTrackMatchPerformancePayload()["cache_hit"] as? Bool, true)
            timingRecords.append([
                "id": id,
                "cold_ms": coldMilliseconds,
                "warm_ms": warmMilliseconds,
                "cold_phases": phasePayload["phases_ms"] ?? [:],
                "cold_counters": phasePayload["counters"] ?? [:]
            ])
        }
        let timingData = try JSONSerialization.data(
            withJSONObject: ["cases": timingRecords],
            options: [.prettyPrinted, .sortedKeys]
        )
        print("TRACK_MATCH_TIMINGS_BEGIN")
        print(String(decoding: timingData, as: UTF8.self))
        print("TRACK_MATCH_TIMINGS_END")
    }

    private func workspaceRoot() -> URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { root.deleteLastPathComponent() }
        return root
    }

    private func jsonMismatch(actual: Any, expected: Any, path: String = "$") -> String? {
        if let actual = actual as? [String: Any], let expected = expected as? [String: Any] {
            let actualKeys = Set(actual.keys)
            let expectedKeys = Set(expected.keys)
            guard actualKeys == expectedKeys else {
                return "\(path) keys differ: actual=\(actualKeys.sorted()) expected=\(expectedKeys.sorted())"
            }
            for key in actualKeys.sorted() {
                if let mismatch = jsonMismatch(
                    actual: actual[key]!,
                    expected: expected[key]!,
                    path: "\(path).\(key)"
                ) {
                    return mismatch
                }
            }
            return nil
        }
        if let actual = actual as? [Any], let expected = expected as? [Any] {
            guard actual.count == expected.count else {
                return "\(path) array count differs: actual=\(actual.count) expected=\(expected.count)"
            }
            for index in actual.indices {
                if let mismatch = jsonMismatch(
                    actual: actual[index],
                    expected: expected[index],
                    path: "\(path)[\(index)]"
                ) {
                    return mismatch
                }
            }
            return nil
        }
        if actual is NSNull, expected is NSNull {
            return nil
        }
        if let actual = actual as? NSNumber, let expected = expected as? NSNumber {
            let actualType = String(cString: actual.objCType)
            let expectedType = String(cString: expected.objCType)
            let actualIsBoolean = actualType == "c"
            let expectedIsBoolean = expectedType == "c"
            guard actualIsBoolean == expectedIsBoolean else {
                return "\(path) boolean/number type differs: actual=\(actual) expected=\(expected)"
            }
            if actualIsBoolean {
                return actual.boolValue == expected.boolValue
                    ? nil
                    : "\(path) boolean differs: actual=\(actual) expected=\(expected)"
            }
            let delta = abs(actual.doubleValue - expected.doubleValue)
            return delta <= 1e-9
                ? nil
                : "\(path) number differs: actual=\(actual) expected=\(expected) delta=\(delta)"
        }
        if let actual = actual as? String, let expected = expected as? String {
            return actual == expected
                ? nil
                : "\(path) string differs: actual=\(actual) expected=\(expected)"
        }
        return String(describing: actual) == String(describing: expected)
            ? nil
            : "\(path) value differs: actual=\(actual) expected=\(expected)"
    }

    private func weatherRequest(hourly: [String], model: String) -> RuntimeRequest {
        RuntimeRequest(
            method: "GET",
            path: "/weather/open-meteo",
            query: [
                "longitude": ["116.6"],
                "hourly": hourly,
                "models": [model],
                "latitude": ["40.1"],
                "ignored": ["not-forwarded"]
            ]
        )
    }

    private func makeTileRouterFixture() -> (
        root: URL,
        cache: SimNavOnlineTileCache,
        router: SimNavRuntimeRouter
    ) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "SimNavTilePerformance-\(UUID().uuidString)",
            isDirectory: true
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PerformanceTileURLProtocol.self]
        let cache = SimNavOnlineTileCache(
            rootDirectory: root.appendingPathComponent("MapCacheV3", isDirectory: true),
            sessionConfiguration: configuration
        )
        let unavailableDatabase = root.appendingPathComponent("unavailable.sqlite")
        let router = SimNavRuntimeRouter(
            plannerService: PlannerService(dataStore: LocalDataStore(databaseURL: unavailableDatabase)),
            onlineTileCache: cache
        )
        return (root, cache, router)
    }

    private func waitForTileHit(
        router: SimNavRuntimeRouter,
        request: RuntimeRequest,
        timeout: TimeInterval
    ) throws -> RuntimeResponse {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            let response = router.handle(request)
            if response.headers["X-Map-Cache"] == "HIT" {
                return response
            }
            Thread.sleep(forTimeInterval: 0.02)
        } while Date() < deadline
        throw NSError(
            domain: "PerformanceRemediationTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Tile did not reach HIT before timeout."]
        )
    }
}

private final class PerformanceResponseCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [RuntimeResponse] = []

    func append(_ response: RuntimeResponse) {
        lock.lock()
        responses.append(response)
        lock.unlock()
    }

    var snapshot: [RuntimeResponse] {
        lock.lock()
        defer { lock.unlock() }
        return responses
    }
}

private final class PerformanceWeatherURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var _requestCount = 0
    private static var responseStatusCode = 200
    private static var responseBodyMarker = "single-flight"
    private static var responseDelay: TimeInterval = 0.25

    static var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _requestCount
    }

    static func reset() {
        lock.lock()
        _requestCount = 0
        responseStatusCode = 200
        responseBodyMarker = "single-flight"
        responseDelay = 0.25
        lock.unlock()
    }

    static func configure(statusCode: Int, bodyMarker: String, delay: TimeInterval) {
        lock.lock()
        responseStatusCode = statusCode
        responseBodyMarker = bodyMarker
        responseDelay = delay
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "api.open-meteo.com"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self._requestCount += 1
        let statusCode = Self.responseStatusCode
        let bodyMarker = Self.responseBodyMarker
        let delay = Self.responseDelay
        Self.lock.unlock()
        Thread.sleep(forTimeInterval: delay)
        let body = Data("{\"marker\":\"\(bodyMarker)\",\"latitude\":[40.1,39.2],\"longitude\":[116.6,91.1],\"hourly\":{\"time\":[\"2026-08-21T00:00\"],\"temperature_2m\":[20.0]}}".utf8)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "application/json",
                "Date": "Fri, 21 Aug 2026 01:00:00 GMT"
            ]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class PerformanceMutableClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date: Date

    init(_ date: Date) {
        self.date = date
    }

    var value: Date {
        lock.lock()
        defer { lock.unlock() }
        return date
    }

    func advance(by interval: TimeInterval) {
        lock.lock()
        date = date.addingTimeInterval(interval)
        lock.unlock()
    }
}

private final class PerformanceTileURLProtocol: URLProtocol {
    static let tileData = Data(
        base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg=="
    )!
    private static let lock = NSLock()
    private static var responseDelay: TimeInterval = 0.35
    private static var _requestCount = 0
    private static var _cancelCount = 0
    private let cancellationLock = NSLock()
    private var cancelled = false

    static var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _requestCount
    }

    static func reset(delay: TimeInterval) {
        lock.lock()
        responseDelay = delay
        _requestCount = 0
        _cancelCount = 0
        lock.unlock()
    }

    static func configure(delay: TimeInterval) {
        lock.lock()
        responseDelay = delay
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        [
            "s3.amazonaws.com",
            "elevation-tiles-prod.s3.amazonaws.com",
            "tile.openstreetmap.org"
        ].contains(request.url?.host ?? "")
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self._requestCount += 1
        let delay = Self.responseDelay
        Self.lock.unlock()
        Thread.sleep(forTimeInterval: delay)
        cancellationLock.lock()
        let wasCancelled = cancelled
        cancellationLock.unlock()
        guard !wasCancelled else { return }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "image/png"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.tileData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
        cancellationLock.lock()
        cancelled = true
        cancellationLock.unlock()
        Self.lock.lock()
        Self._cancelCount += 1
        Self.lock.unlock()
    }
}
