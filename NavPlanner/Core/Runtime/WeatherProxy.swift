import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class SimNavWeatherProxy: @unchecked Sendable {
    private struct CacheEntry {
        let response: RuntimeResponse
        let storedAt: Date
    }

    private static let allowedQueryNames = Set([
        "latitude",
        "longitude",
        "hourly",
        "forecast_days",
        "timezone",
        "wind_speed_unit",
        "precipitation_unit",
        "models"
    ])

    private let session: URLSession
    private let baseURL: URL
    private let freshTTL: TimeInterval
    private let staleTTL: TimeInterval
    private let requestTimeout: TimeInterval
    private let waitTimeout: TimeInterval
    private let now: @Sendable () -> Date
    private let lock = NSLock()
    private var cache: [String: CacheEntry] = [:]
    private var inFlight: [String: WeatherFlight] = [:]
    private let maximumCacheEntries = 64

    init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://api.open-meteo.com/v1/forecast")!,
        freshTTL: TimeInterval = 5 * 60,
        staleTTL: TimeInterval = 30 * 60,
        requestTimeout: TimeInterval = 14,
        waitTimeout: TimeInterval = 16,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.session = session
        self.baseURL = baseURL
        self.freshTTL = max(0, freshTTL)
        self.staleTTL = max(freshTTL, staleTTL)
        self.requestTimeout = max(0.1, requestTimeout)
        self.waitTimeout = max(requestTimeout, waitTimeout)
        self.now = now
    }

    func response(for request: RuntimeRequest) -> RuntimeResponse {
        guard request.method == "GET" else {
            return jsonError("Weather proxy requires GET.", status: 405)
        }
        let queryItems = canonicalQueryItems(request.query)
        guard queryItems.contains(where: { $0.name == "latitude" }),
              queryItems.contains(where: { $0.name == "longitude" }),
              queryItems.contains(where: { $0.name == "hourly" }) else {
            return jsonError("Invalid weather request.", status: 400)
        }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems
        guard let url = components?.url else {
            return jsonError("Invalid weather URL.", status: 400)
        }

        let key = queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
        let requestDate = now()
        var staleEntry: CacheEntry?
        var flight: WeatherFlight?
        var leadsFlight = false

        lock.lock()
        if let entry = cache[key] {
            let age = max(0, requestDate.timeIntervalSince(entry.storedAt))
            if age <= freshTTL {
                lock.unlock()
                return response(entry.response, cacheState: "HIT", age: age)
            }
            if age <= staleTTL {
                staleEntry = entry
            } else {
                cache.removeValue(forKey: key)
            }
        }
        if let active = inFlight[key] {
            flight = active
        } else {
            let active = WeatherFlight()
            inFlight[key] = active
            flight = active
            leadsFlight = true
        }
        lock.unlock()

        guard let flight else {
            return jsonError("Weather proxy state error.", status: 500)
        }
        if !leadsFlight {
            if let completed = flight.wait(timeout: waitTimeout + 0.5) {
                return completed
            }
            if let staleEntry {
                return staleResponse(staleEntry, reason: "coalesced request timeout")
            }
            return jsonError("Weather request timed out.", status: 504)
        }

        let fetched = fetch(url: url)
        let finalResponse: RuntimeResponse
        if (200..<300).contains(fetched.status) {
            let stored = response(fetched, cacheState: "MISS", age: 0)
            lock.lock()
            cache[key] = CacheEntry(response: stored, storedAt: now())
            trimCacheIfNeeded()
            lock.unlock()
            finalResponse = stored
        } else if let staleEntry {
            finalResponse = staleResponse(staleEntry, reason: "upstream status \(fetched.status)")
        } else {
            finalResponse = fetched
        }

        lock.lock()
        if inFlight[key] === flight {
            inFlight.removeValue(forKey: key)
        }
        lock.unlock()
        flight.complete(finalResponse)
        return finalResponse
    }

    private func canonicalQueryItems(_ query: [String: [String]]) -> [URLQueryItem] {
        query.keys.sorted().flatMap { name -> [URLQueryItem] in
            guard Self.allowedQueryNames.contains(name) else { return [] }
            return (query[name] ?? [])
                .filter { !$0.isEmpty && $0.count <= 900 }
                .sorted()
                .map { URLQueryItem(name: name, value: $0) }
        }
    }

    private func fetch(url: URL) -> RuntimeResponse {
        var upstreamRequest = URLRequest(url: url)
        upstreamRequest.timeoutInterval = requestTimeout
        upstreamRequest.cachePolicy = .reloadIgnoringLocalCacheData
        upstreamRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        upstreamRequest.setValue("SimNav Studio weather proxy", forHTTPHeaderField: "User-Agent")

        let semaphore = DispatchSemaphore(value: 0)
        let result = WeatherResult()
        let task = session.dataTask(with: upstreamRequest) { data, response, error in
            result.store(data: data, response: response, error: error)
            semaphore.signal()
        }
        task.resume()
        guard semaphore.wait(timeout: .now() + waitTimeout) == .success else {
            task.cancel()
            return jsonError("Weather request timed out.", status: 504)
        }
        let output = result.value()
        if let error = output.error {
            return jsonError("Weather request failed: \(error.localizedDescription)", status: 502)
        }
        guard let upstreamResponse = output.response else {
            return jsonError("Weather service returned no HTTP response.", status: 502)
        }

        let contentType = upstreamResponse.value(forHTTPHeaderField: "Content-Type") ?? "application/json"
        var headers = [
            "Cache-Control": "no-store",
            "Content-Type": contentType,
            "X-Weather-Source": "Open-Meteo"
        ]
        if let date = upstreamResponse.value(forHTTPHeaderField: "Date") {
            headers["Date"] = date
            headers["X-Weather-Updated"] = date
        }
        return RuntimeResponse(
            status: upstreamResponse.statusCode,
            headers: headers,
            body: output.data ?? Data()
        )
    }

    private func staleResponse(_ entry: CacheEntry, reason: String) -> RuntimeResponse {
        var stale = response(
            entry.response,
            cacheState: "STALE",
            age: max(0, now().timeIntervalSince(entry.storedAt))
        )
        stale.headers["Warning"] = "110 - Response is stale"
        stale.headers["X-Weather-Stale-Reason"] = reason
        return stale
    }

    private func response(
        _ original: RuntimeResponse,
        cacheState: String,
        age: TimeInterval
    ) -> RuntimeResponse {
        var output = original
        output.headers["X-Weather-Cache"] = cacheState
        output.headers["X-Weather-Cache-Age"] = String(max(0, Int(age.rounded(.down))))
        return output
    }

    private func trimCacheIfNeeded() {
        guard cache.count > maximumCacheEntries else { return }
        let overflow = cache.count - maximumCacheEntries
        let oldestKeys = cache
            .sorted { $0.value.storedAt < $1.value.storedAt }
            .prefix(overflow)
            .map(\.key)
        oldestKeys.forEach { cache.removeValue(forKey: $0) }
    }

    private func jsonError(_ message: String, status: Int) -> RuntimeResponse {
        let data = (try? JSONSerialization.data(
            withJSONObject: ["error": message],
            options: [.sortedKeys]
        )) ?? Data("{\"error\":\"Weather proxy error\"}".utf8)
        return RuntimeResponse(
            status: status,
            headers: [
                "Cache-Control": "no-store",
                "Content-Type": "application/json",
                "X-Weather-Cache": "MISS"
            ],
            body: data
        )
    }
}

private final class WeatherFlight: @unchecked Sendable {
    private let condition = NSCondition()
    private var response: RuntimeResponse?

    func complete(_ response: RuntimeResponse) {
        condition.lock()
        self.response = response
        condition.broadcast()
        condition.unlock()
    }

    func wait(timeout: TimeInterval) -> RuntimeResponse? {
        let deadline = Date().addingTimeInterval(timeout)
        condition.lock()
        defer { condition.unlock() }
        while response == nil {
            if !condition.wait(until: deadline) {
                return nil
            }
        }
        return response
    }
}

private final class WeatherResult: @unchecked Sendable {
    private let lock = NSLock()
    private var data: Data?
    private var response: HTTPURLResponse?
    private var error: Error?

    func store(data: Data?, response: URLResponse?, error: Error?) {
        lock.lock()
        self.data = data
        self.response = response as? HTTPURLResponse
        self.error = error
        lock.unlock()
    }

    func value() -> (data: Data?, response: HTTPURLResponse?, error: Error?) {
        lock.lock()
        defer { lock.unlock() }
        return (data, response, error)
    }
}
