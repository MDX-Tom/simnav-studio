import Foundation

final class LocalDataStore: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.navplanner.local-data", qos: .userInitiated)
    private let fileManager: FileManager
    private let bundle: Bundle
    private var database: SQLiteDatabase?
    private(set) var databaseURL: URL?
    private(set) var startupError: String?

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
            let supportRoot = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("NavPlanner", isDirectory: true)
            let databaseDirectory = supportRoot.appendingPathComponent("Database", isDirectory: true)
            try fileManager.createDirectory(at: databaseDirectory, withIntermediateDirectories: true)

            let cleanName = source.deletingPathExtension().lastPathComponent
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
                .joined(separator: "_")
            let destinationName = (cleanName.isEmpty ? "navdata_custom" : cleanName) + ".sqlite"
            let destination = databaseDirectory.appendingPathComponent(destinationName)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: source, to: destination)

            let nextDatabase = try SQLiteDatabase(path: destination)
            database = nextDatabase
            databaseURL = destination
            startupError = nil
            return statusPayloadLocked(message: "已切换本地导航数据库：\(destination.lastPathComponent)")
        }
    }

    private func prepareDatabase() throws {
        let supportRoot = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NavPlanner", isDirectory: true)
        let databaseDirectory = supportRoot.appendingPathComponent("Database", isDirectory: true)
        try fileManager.createDirectory(at: databaseDirectory, withIntermediateDirectories: true)

        let destination = databaseDirectory.appendingPathComponent("navdata.sqlite")
        if !fileManager.fileExists(atPath: destination.path) {
            guard let source = bundle.url(
                forResource: "navdata",
                withExtension: "sqlite",
                subdirectory: "Database"
            ) else {
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
}
