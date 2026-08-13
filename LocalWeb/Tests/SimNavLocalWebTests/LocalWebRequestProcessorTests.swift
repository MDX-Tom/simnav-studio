import Foundation
#if canImport(SQLite3)
import SQLite3
#elseif canImport(CSQLite)
import CSQLite
#endif
import XCTest
@testable import SimNavLocalWeb

final class LocalWebRequestProcessorTests: XCTestCase {
    private let token = "processorfixture0123456789abcdef"

    func testSharedProcessorEnforcesSecurityAndServesCanonicalUI() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.dataRoot) }
        let processor = LocalWebRequestProcessor(settings: fixture.settings)

        let health = processor.response(to: request(path: "/healthz"))
        XCTAssertEqual(health.status, 200)
        XCTAssertEqual(health.body, Data("{\"status\":\"ok\"}".utf8))
        XCTAssertEqual(health.headers["X-Content-Type-Options"], "nosniff")

        var invalidHost = request(path: "/healthz")
        invalidHost.authority = "attacker.invalid"
        XCTAssertEqual(processor.response(to: invalidHost).status, 403)

        var invalidOrigin = request(path: "/api/header")
        invalidOrigin.headers["Origin"] = "http://attacker.invalid"
        XCTAssertEqual(processor.response(to: invalidOrigin).status, 403)

        let index = processor.response(to: request(path: "/"))
        XCTAssertEqual(index.status, 200)
        let html = String(decoding: index.body, as: UTF8.self)
        XCTAssertTrue(html.contains("SimNav Studio"))
        XCTAssertTrue(html.contains(token))
        XCTAssertFalse(html.contains("__SIMNAV_WRITE_TOKEN__"))

        var preflight = request(method: "OPTIONS", path: "/api/databases/import")
        preflight.headers["Origin"] = "http://127.0.0.1:8010"
        let preflightResponse = processor.response(to: preflight)
        XCTAssertEqual(preflightResponse.status, 204)
        XCTAssertEqual(preflightResponse.headers["Access-Control-Allow-Origin"], preflight.headers["Origin"])
        XCTAssertTrue(preflightResponse.headers["Access-Control-Allow-Headers"]?.contains("X-SimNav-Filename") == true)
    }

    func testSharedUploadPlanActivatesDatabaseAcrossProcessorRestart() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.dataRoot) }
        let source = FileManager.default.temporaryDirectory.appendingPathComponent(
            "SimNavProcessorDatabase-\(UUID().uuidString).s3db"
        )
        defer { try? FileManager.default.removeItem(at: source) }
        try makeNavigationDatabaseFixture(at: source)

        let processor = LocalWebRequestProcessor(settings: fixture.settings)
        var uploadRequest = request(method: "POST", path: "/api/databases/import")
        uploadRequest.headers["Origin"] = "http://127.0.0.1:8010"
        uploadRequest.headers["X-SimNav-Token"] = token
        uploadRequest.headers["X-SimNav-Filename"] = "processor-cycle.s3db"

        guard case .upload(let plan) = processor.uploadDecision(for: uploadRequest) else {
            return XCTFail("Expected the shared processor to create an upload plan.")
        }
        defer { try? FileManager.default.removeItem(at: plan.rootURL) }
        try FileManager.default.createDirectory(at: plan.rootURL, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: source, to: plan.fileURL)
        uploadRequest.bodyFileURL = plan.fileURL
        let imported = processor.response(to: uploadRequest)
        XCTAssertEqual(imported.status, 200)
        let importedPayload = try jsonObject(imported.body)
        XCTAssertEqual(importedPayload["database_name"] as? String, "processor_cycle.sqlite")

        let restarted = LocalWebRequestProcessor(settings: fixture.settings)
        let header = restarted.response(to: request(path: "/api/header"))
        XCTAssertEqual(header.status, 200)
        let headerPayload = try jsonObject(header.body)
        XCTAssertEqual(headerPayload["current_airac"] as? String, "9999")
        XCTAssertEqual(headerPayload["revision"] as? String, "processor-restart")
        XCTAssertEqual(headerPayload["database_name"] as? String, "processor_cycle.sqlite")

        var unsafeUpload = uploadRequest
        unsafeUpload.headers["X-SimNav-Filename"] = "..%5Cescape.s3db"
        guard case .reject(let unsafeResponse) = processor.uploadDecision(for: unsafeUpload) else {
            return XCTFail("Expected Windows-style traversal to be rejected.")
        }
        XCTAssertEqual(unsafeResponse.status, 400)
    }

    private func request(
        method: String = "GET",
        path: String
    ) -> LocalWebTransportRequest {
        LocalWebTransportRequest(
            method: method,
            target: path,
            authority: "127.0.0.1:8010",
            headers: ["Host": "127.0.0.1:8010"]
        )
    }

    private func makeFixture() throws -> (settings: LocalWebSettings, dataRoot: URL) {
        let dataRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
            "SimNavProcessorTests-\(UUID().uuidString)",
            isDirectory: true
        )
        return (
            LocalWebSettings(
                port: 8010,
                bindHost: "127.0.0.1",
                webRoot: workspaceRoot().appendingPathComponent("NavPlanner/Resources/Web"),
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

    private func jsonObject(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func makeNavigationDatabaseFixture(at url: URL) throws {
        var database: OpaquePointer?
        guard sqlite3_open(url.path, &database) == SQLITE_OK, let database else {
            throw NSError(domain: "LocalWebRequestProcessorTests", code: 1)
        }
        defer { sqlite3_close(database) }
        let sql = """
        CREATE TABLE tbl_header (current_airac TEXT, revision TEXT);
        INSERT INTO tbl_header VALUES ('9999', 'processor-restart');
        CREATE TABLE tbl_airports (airport_identifier TEXT);
        CREATE TABLE tbl_runways (airport_identifier TEXT);
        CREATE TABLE tbl_enroute_waypoints (waypoint_identifier TEXT);
        CREATE TABLE tbl_enroute_airways (route_identifier TEXT);
        """
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw NSError(
                domain: "LocalWebRequestProcessorTests",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(database))]
            )
        }
    }
}
