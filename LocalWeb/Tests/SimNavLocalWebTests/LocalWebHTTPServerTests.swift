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

            let script = try await client.execute(uri: "/app.js", method: .get)
            let scriptData = Data(script.body.readableBytesView)
            let sourceScript = try Data(
                contentsOf: fixture.settings.webRoot.appendingPathComponent("app.js")
            )
            XCTAssertEqual(script.status, .ok)
            XCTAssertEqual(scriptData, sourceScript)

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
            XCTAssertTrue(String(decoding: uiZoomData, as: UTF8.self)
                .contains("window.SimNavUIZoom"))
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
#endif
