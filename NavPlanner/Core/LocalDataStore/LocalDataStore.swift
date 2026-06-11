import Foundation

final class LocalDataStore: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.navplanner.local-data", qos: .userInitiated)
    private let fileManager: FileManager
    private let bundle: Bundle
    private var database: SQLiteDatabase?
    private(set) var databaseURL: URL?
    private(set) var startupError: String?
    private let bundledDatabaseName = "navdata.sqlite"

    init(bundle: Bundle = .main, fileManager: FileManager = .default) {
        self.bundle = bundle
        self.fileManager = fileManager

        do {
            try prepareDatabase()
        } catch {
            startupError = error.localizedDescription
        }
    }

    init(databaseURL: URL, fileManager: FileManager = .default) {
        self.bundle = .main
        self.fileManager = fileManager

        do {
            self.databaseURL = databaseURL
            self.database = try SQLiteDatabase(path: databaseURL)
        } catch {
            startupError = error.localizedDescription
        }
    }

    func read<T>(fallback: T, _ work: (SQLiteDatabase) throws -> T) -> T {
        queue.sync {
            guard let database else {
                return fallback
            }
            do {
                return try work(database)
            } catch {
                return fallback
            }
        }
    }

    func statusPayload() -> [String: Any] {
        queue.sync {
            [
                "local_status": database == nil ? "missing_database" : "ready",
                "database_path": databaseURL?.path ?? "",
                "database_name": databaseURL?.lastPathComponent ?? "",
                "message": startupError ?? "本地导航数据库已就绪"
            ]
        }
    }

    func importDatabase(from source: URL) throws -> [String: Any] {
        try queue.sync {
            let databaseDirectory = try databaseDirectoryLocked()

            let cleanName = source.deletingPathExtension().lastPathComponent
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
                .joined(separator: "_")
            let baseName = cleanName.isEmpty || cleanName == "navdata" ? "navdata_custom" : cleanName
            let destination = uniqueDatabaseURLLocked(baseName: baseName, directory: databaseDirectory)
            try fileManager.copyItem(at: source, to: destination)

            let nextDatabase = try SQLiteDatabase(path: destination)
            database = nextDatabase
            databaseURL = destination
            startupError = nil
            var payload = statusPayloadLocked(message: "已切换本地导航数据库：\(destination.lastPathComponent)")
            payload["databases"] = try databaseListPayloadLocked(query: "", limit: 200)
            return payload
        }
    }

    func databaseListPayload(query: String = "", limit: Int = 200) -> [String: Any] {
        do {
            return try queue.sync {
                try databaseListPayloadLocked(query: query, limit: limit)
            }
        } catch {
            return [
                "error": "读取本地数据库列表失败：\(error.localizedDescription)",
                "items": [],
                "file_count": 0,
                "size_bytes": 0,
                "database": statusPayload()
            ]
        }
    }

    func selectDatabase(named name: String) throws -> [String: Any] {
        try queue.sync {
            let databaseDirectory = try databaseDirectoryLocked()
            let target = try databaseFileURLLocked(name: name, directory: databaseDirectory)
            guard fileManager.fileExists(atPath: target.path) else {
                throw CocoaError(.fileNoSuchFile, userInfo: [
                    NSLocalizedDescriptionKey: "数据库文件不存在：\(target.lastPathComponent)"
                ])
            }
            let nextDatabase = try SQLiteDatabase(path: target)
            database = nextDatabase
            databaseURL = target
            startupError = nil
            var payload = statusPayloadLocked(message: "已切换本地导航数据库：\(target.lastPathComponent)")
            payload["databases"] = try databaseListPayloadLocked(query: "", limit: 200)
            return payload
        }
    }

    func deleteDatabase(named name: String) throws -> [String: Any] {
        try queue.sync {
            let databaseDirectory = try databaseDirectoryLocked()
            let target = try databaseFileURLLocked(name: name, directory: databaseDirectory)
            let activePath = databaseURL?.standardizedFileURL.path ?? ""
            if target.standardizedFileURL.path == activePath {
                throw CocoaError(.fileWriteNoPermission, userInfo: [
                    NSLocalizedDescriptionKey: "当前使用中的数据库不能删除。"
                ])
            }
            if target.lastPathComponent == bundledDatabaseName {
                throw CocoaError(.fileWriteNoPermission, userInfo: [
                    NSLocalizedDescriptionKey: "内置数据库不能删除。"
                ])
            }
            guard fileManager.fileExists(atPath: target.path) else {
                throw CocoaError(.fileNoSuchFile, userInfo: [
                    NSLocalizedDescriptionKey: "数据库文件不存在：\(target.lastPathComponent)"
                ])
            }
            try fileManager.removeItem(at: target)
            return [
                "message": "已删除本地数据库：\(target.lastPathComponent)",
                "database": statusPayloadLocked(),
                "databases": try databaseListPayloadLocked(query: "", limit: 200)
            ]
        }
    }

    func restoreBundledDatabase() throws -> [String: Any] {
        try queue.sync {
            let databaseDirectory = try databaseDirectoryLocked()
            let destination = databaseDirectory.appendingPathComponent(bundledDatabaseName)
            guard let source = bundledDatabaseURLLocked() else {
                throw CocoaError(.fileNoSuchFile, userInfo: [
                    NSLocalizedDescriptionKey: "App Bundle 中缺少 Database/navdata.sqlite"
                ])
            }
            database = nil
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: source, to: destination)
            database = try SQLiteDatabase(path: destination)
            databaseURL = destination
            startupError = nil
            var payload = statusPayloadLocked(message: "已恢复并启用内置导航数据库：\(bundledDatabaseName)")
            payload["databases"] = try databaseListPayloadLocked(query: "", limit: 200)
            return payload
        }
    }

    private func prepareDatabase() throws {
        let databaseDirectory = try databaseDirectoryLocked()
        let destination = databaseDirectory.appendingPathComponent(bundledDatabaseName)
        if !fileManager.fileExists(atPath: destination.path) {
            guard let source = bundledDatabaseURLLocked() else {
                throw CocoaError(.fileNoSuchFile, userInfo: [
                    NSLocalizedDescriptionKey: "App Bundle 中缺少 Database/navdata.sqlite"
                ])
            }
            try fileManager.copyItem(at: source, to: destination)
        }

        databaseURL = destination
        database = try SQLiteDatabase(path: destination)
    }

    private func statusPayloadLocked(message: String? = nil) -> [String: Any] {
        [
            "local_status": database == nil ? "missing_database" : "ready",
            "database_path": databaseURL?.path ?? "",
            "database_name": databaseURL?.lastPathComponent ?? "",
            "message": message ?? startupError ?? "本地导航数据库已就绪"
        ]
    }

    private func databaseDirectoryLocked() throws -> URL {
        let supportRoot = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NavPlanner", isDirectory: true)
        let databaseDirectory = supportRoot.appendingPathComponent("Database", isDirectory: true)
        try fileManager.createDirectory(at: databaseDirectory, withIntermediateDirectories: true)
        return databaseDirectory
    }

    private func bundledDatabaseURLLocked() -> URL? {
        bundle.url(
            forResource: "navdata",
            withExtension: "sqlite",
            subdirectory: "Database"
        )
    }

    private func uniqueDatabaseURLLocked(baseName: String, directory: URL) -> URL {
        var index = 0
        while true {
            let suffix = index == 0 ? "" : "_\(index + 1)"
            let candidate = directory.appendingPathComponent("\(baseName)\(suffix).sqlite")
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }

    private func databaseFileURLLocked(name: String, directory: URL) throws -> URL {
        let fileName = URL(fileURLWithPath: name).lastPathComponent
        let ext = URL(fileURLWithPath: fileName).pathExtension.lowercased()
        guard ["sqlite", "sqlite3", "s3db", "db"].contains(ext) else {
            throw CocoaError(.fileReadUnsupportedScheme, userInfo: [
                NSLocalizedDescriptionKey: "不支持的数据库文件类型：\(fileName)"
            ])
        }
        let target = directory.appendingPathComponent(fileName).standardizedFileURL
        guard target.deletingLastPathComponent().path == directory.standardizedFileURL.path else {
            throw CocoaError(.fileReadNoPermission, userInfo: [
                NSLocalizedDescriptionKey: "数据库文件路径无效。"
            ])
        }
        return target
    }

    private func databaseListPayloadLocked(query: String, limit: Int) throws -> [String: Any] {
        let databaseDirectory = try databaseDirectoryLocked()
        let rawItems = (try? fileManager.contentsOfDirectory(
            at: databaseDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        let queryText = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let currentPath = databaseURL?.standardizedFileURL.path ?? ""
        var items = rawItems
            .filter { ["sqlite", "sqlite3", "s3db", "db"].contains($0.pathExtension.lowercased()) }
            .compactMap { databaseFileInfoLocked(url: $0, currentPath: currentPath) }
            .filter { item in
                guard !queryText.isEmpty else { return true }
                return [
                    item["name"],
                    item["current_airac"],
                    item["revision"],
                    item["message"]
                ].contains { value in
                    String(describing: value ?? "").lowercased().contains(queryText)
                }
            }
            .sorted { lhs, rhs in
                let lhsActive = (lhs["active"] as? Bool) == true
                let rhsActive = (rhs["active"] as? Bool) == true
                if lhsActive != rhsActive {
                    return lhsActive
                }
                return String(describing: lhs["name"] ?? "") < String(describing: rhs["name"] ?? "")
            }
        let totalCount = items.count
        let totalSize = items.reduce(0) { partial, item in
            partial + (item["size_bytes"] as? Int ?? 0)
        }
        if items.count > limit {
            items = Array(items.prefix(limit))
        }
        return [
            "root": databaseDirectory.path,
            "items": items,
            "file_count": totalCount,
            "size_bytes": totalSize,
            "database": statusPayloadLocked(),
            "message": "本地数据库列表已读取。"
        ]
    }

    private func databaseFileInfoLocked(url: URL, currentPath: String) -> [String: Any]? {
        guard ((try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? true) else {
            return nil
        }
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let active = url.standardizedFileURL.path == currentPath
        let builtIn = url.lastPathComponent == bundledDatabaseName
        var item: [String: Any] = [
            "name": url.lastPathComponent,
            "path": url.path,
            "size_bytes": values?.fileSize ?? 0,
            "modified_at": Int((values?.contentModificationDate ?? Date.distantPast).timeIntervalSince1970),
            "active": active,
            "built_in": builtIn,
            "deletable": !active && !builtIn,
            "valid": true
        ]
        do {
            let checkDatabase = try SQLiteDatabase(path: url)
            if let header = try checkDatabase.first(sql: "select * from tbl_header limit 1") {
                item["current_airac"] = header["current_airac"] ?? NSNull()
                item["revision"] = header["revision"] ?? NSNull()
            }
        } catch {
            item["valid"] = false
            item["message"] = error.localizedDescription
        }
        return item
    }
}
