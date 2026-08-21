import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if !os(Windows)
import Hummingbird
import HummingbirdTesting
import XCTest
@testable import SimNavCore

final class FR24PerformanceTests: XCTestCase {
    func testRouteScheduleBranchesRunConcurrentlyAndWarmQueryUsesSessionScopedCache() async throws {
        let recorder = FR24ScheduleTimingRecorder()
        let upstreamRouter = Router()
        upstreamRouter.get("/common/v1/airport.json") { request, _ in
            let decodedTarget = request.uri.string.removingPercentEncoding ?? request.uri.string
            let mode = decodedTarget.contains("plugin-setting[schedule][mode]=arrivals")
                ? "arrivals"
                : "departures"
            await recorder.begin(mode: mode)
            try await Task.sleep(for: .milliseconds(350))
            await recorder.end(mode: mode)
            let body = try Self.scheduleFixtureJSON(mode: mode)
            var headers: HTTPFields = [:]
            headers[.contentType] = "application/json; charset=utf-8"
            return Response(
                status: .ok,
                headers: headers,
                body: .init(byteBuffer: ByteBuffer(bytes: body))
            )
        }
        let upstream = Application(router: upstreamRouter)

        try await upstream.test(.live) { client in
            let port = try XCTUnwrap(client.port)
            let baseURL = try XCTUnwrap(URL(string: "http://localhost:\(port)"))
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(
                "SimNavFR24PerformanceTests-\(UUID().uuidString)",
                isDirectory: true
            )
            defer { try? FileManager.default.removeItem(at: root) }
            let clock = FR24MutableClock(Date(timeIntervalSince1970: 1_787_280_000))
            let service = FR24Service(
                rootDirectory: root.appendingPathComponent("FR24", isDirectory: true),
                sessionFileURL: root.appendingPathComponent("Config/fr24-session.json"),
                apiBaseURL: baseURL,
                routeCacheTTL: 1,
                now: { clock.value }
            )
            let routeAirports: [String: Any] = [
                "departure": [
                    "ident": "ZBAA", "icao": "ZBAA", "iata": "PEK",
                    "schedule_code": "PEK", "codes": ["ZBAA", "PEK"]
                ],
                "arrival": [
                    "ident": "ZULS", "icao": "ZULS", "iata": "LXA",
                    "schedule_code": "LXA", "codes": ["ZULS", "LXA"]
                ]
            ]

            let coldStart = DispatchTime.now().uptimeNanoseconds
            let coldResults = await withTaskGroup(of: [String: Any].self) { group in
                for _ in 0..<5 {
                    group.addTask {
                        service.searchPayload(routeAirports: routeAirports, limit: 2)
                    }
                }
                var values: [[String: Any]] = []
                for await value in group { values.append(value) }
                return values
            }
            let coldMilliseconds = Double(DispatchTime.now().uptimeNanoseconds - coldStart) / 1_000_000
            let cold = try XCTUnwrap(coldResults.first)
            XCTAssertEqual(coldResults.count, 5)
            XCTAssertTrue(coldResults.allSatisfy { $0["error"] == nil })
            XCTAssertNil(cold["error"])
            let flights = try XCTUnwrap(cold["flights"] as? [[String: Any]])
            XCTAssertEqual(flights.compactMap { $0["fr24_id"] as? String }, ["arr002", "dep001"])
            let coldSnapshot = await recorder.snapshot()
            XCTAssertEqual(coldSnapshot.requestCount, 2)
            XCTAssertEqual(coldSnapshot.peakConcurrent, 2)
            XCTAssertLessThan(coldMilliseconds, 600)

            let warmStart = DispatchTime.now().uptimeNanoseconds
            let warm = service.searchPayload(routeAirports: routeAirports, limit: 2)
            let warmMilliseconds = Double(DispatchTime.now().uptimeNanoseconds - warmStart) / 1_000_000
            XCTAssertNil(warm["error"])
            let warmSnapshot = await recorder.snapshot()
            XCTAssertEqual(warmSnapshot.requestCount, 2)
            XCTAssertLessThan(warmMilliseconds, 100)

            _ = service.updateAccessPayload(webCookie: "simnav_session=changed", frPl: nil)
            let refreshed = service.searchPayload(routeAirports: routeAirports, limit: 2)
            XCTAssertNil(refreshed["error"])
            let refreshedSnapshot = await recorder.snapshot()
            XCTAssertEqual(refreshedSnapshot.requestCount, 4)

            clock.advance(by: 2)
            let expired = service.searchPayload(routeAirports: routeAirports, limit: 2)
            XCTAssertNil(expired["error"])
            let expiredSnapshot = await recorder.snapshot()
            XCTAssertEqual(expiredSnapshot.requestCount, 6)
            print(
                "FR24_PERFORMANCE cold_ms=\(coldMilliseconds) warm_ms=\(warmMilliseconds) "
                + "peak_concurrent=\(coldSnapshot.peakConcurrent) request_count=\(expiredSnapshot.requestCount)"
            )
        }
    }

    private static func scheduleFixtureJSON(mode: String) throws -> Data {
        let isArrival = mode == "arrivals"
        let identifier = isArrival ? "arr002" : "dep001"
        let timestamp = isArrival ? 1_786_590_000 : 1_786_580_000
        let flight: [String: Any] = [
            "identification": [
                "id": identifier,
                "number": ["default": isArrival ? "CA4002" : "CA4001"],
                "callsign": isArrival ? "CCA4002" : "CCA4001"
            ],
            "airline": ["name": "Fixture Air"],
            "aircraft": ["model": ["code": "A320"], "registration": isArrival ? "B-0002" : "B-0001"],
            "airport": [
                "origin": ["code": ["icao": "ZBAA", "iata": "PEK"], "name": "Beijing"],
                "destination": ["code": ["icao": "ZULS", "iata": "LXA"], "name": "Lhasa"]
            ],
            "time": [
                "scheduled": ["departure": timestamp, "arrival": timestamp + 7_200],
                "real": ["departure": timestamp, "arrival": timestamp + 7_200]
            ],
            "status": ["text": "Landed"]
        ]
        let payload: [String: Any] = [
            "result": [
                "response": [
                    "airport": [
                        "pluginData": [
                            "schedule": [mode: ["data": [["flight": flight]]]]
                        ]
                    ]
                ]
            ]
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    }
}

private final class FR24MutableClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date: Date

    init(_ date: Date) { self.date = date }

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

private actor FR24ScheduleTimingRecorder {
    private var requestCount = 0
    private var active = 0
    private var peakConcurrent = 0
    private var starts: [String: [UInt64]] = [:]
    private var ends: [String: [UInt64]] = [:]

    func begin(mode: String) {
        requestCount += 1
        active += 1
        peakConcurrent = max(peakConcurrent, active)
        starts[mode, default: []].append(DispatchTime.now().uptimeNanoseconds)
    }

    func end(mode: String) {
        ends[mode, default: []].append(DispatchTime.now().uptimeNanoseconds)
        active = max(0, active - 1)
    }

    func snapshot() -> (requestCount: Int, peakConcurrent: Int) {
        (requestCount, peakConcurrent)
    }
}
#endif
