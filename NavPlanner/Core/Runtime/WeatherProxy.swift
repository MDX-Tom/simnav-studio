import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class SimNavWeatherProxy: @unchecked Sendable {
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

    func response(for request: RuntimeRequest) -> RuntimeResponse {
        guard request.method == "GET" else {
            return jsonError("Weather proxy requires GET.", status: 405)
        }
        var queryItems: [URLQueryItem] = []
        for name in request.query.keys.sorted() where Self.allowedQueryNames.contains(name) {
            for value in request.query[name] ?? [] where !value.isEmpty && value.count <= 900 {
                queryItems.append(URLQueryItem(name: name, value: value))
            }
        }
        guard queryItems.contains(where: { $0.name == "latitude" }),
              queryItems.contains(where: { $0.name == "longitude" }),
              queryItems.contains(where: { $0.name == "hourly" }) else {
            return jsonError("Invalid weather request.", status: 400)
        }

        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = queryItems
        guard let url = components?.url else {
            return jsonError("Invalid weather URL.", status: 400)
        }

        var upstreamRequest = URLRequest(url: url)
        upstreamRequest.timeoutInterval = 14
        upstreamRequest.cachePolicy = .reloadIgnoringLocalCacheData
        upstreamRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        upstreamRequest.setValue("SimNav Studio weather proxy", forHTTPHeaderField: "User-Agent")

        let semaphore = DispatchSemaphore(value: 0)
        let result = WeatherResult()
        URLSession.shared.dataTask(with: upstreamRequest) { data, response, error in
            result.store(data: data, response: response, error: error)
            semaphore.signal()
        }.resume()
        guard semaphore.wait(timeout: .now() + 16) == .success else {
            return jsonError("Weather request timed out.", status: 504)
        }
        let output = result.value()
        if let error = output.error {
            return jsonError("Weather request failed: \(error.localizedDescription)", status: 502)
        }
        guard let response = output.response else {
            return jsonError("Weather service returned no HTTP response.", status: 502)
        }

        let contentType = response.value(forHTTPHeaderField: "Content-Type") ?? "application/json"
        var headers = [
            "Cache-Control": "no-store",
            "Content-Type": contentType,
            "X-Weather-Source": "Open-Meteo"
        ]
        if let date = response.value(forHTTPHeaderField: "Date") {
            headers["Date"] = date
            headers["X-Weather-Updated"] = date
        }
        return RuntimeResponse(
            status: response.statusCode,
            headers: headers,
            body: output.data ?? Data()
        )
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
                "Content-Type": "application/json"
            ],
            body: data
        )
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
