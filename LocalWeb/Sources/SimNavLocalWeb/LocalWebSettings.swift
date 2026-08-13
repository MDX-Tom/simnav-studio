import Foundation
import SimNavCore

struct LocalWebSettings: Sendable {
    static let defaultPort = 8010

    let port: Int
    let bindHost: String
    let webRoot: URL
    let dataRoot: URL
    let bundledDatabaseURL: URL?
    let writeToken: String

    var runtimeConfiguration: RuntimeConfiguration {
        RuntimeConfiguration(
            dataRoot: dataRoot,
            bundledDatabaseURL: bundledDatabaseURL,
            webRoot: webRoot
        )
    }

    static func load(
        arguments: [String] = Array(ProcessInfo.processInfo.arguments.dropFirst()),
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) throws -> LocalWebSettings {
        var port = Int(environment["SIMNAV_WEB_PORT"] ?? "") ?? defaultPort
        var dataRoot = environment["SIMNAV_DATA_DIR"].flatMap(fileURL)
        var databaseURL = environment["SIMNAV_DATABASE"].flatMap(fileURL)
        var webRoot = environment["SIMNAV_WEB_ROOT"].flatMap(fileURL)
        var writeToken = environment["SIMNAV_WRITE_TOKEN"]
        let bindHost = try validatedBindHost(environment: environment)

        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--port":
                port = try integerValue(after: argument, arguments: arguments, index: &index)
            case "--database":
                databaseURL = try pathValue(after: argument, arguments: arguments, index: &index)
            case "--data-dir":
                dataRoot = try pathValue(after: argument, arguments: arguments, index: &index)
            case "--web-root":
                webRoot = try pathValue(after: argument, arguments: arguments, index: &index)
            case "--write-token":
                writeToken = try stringValue(after: argument, arguments: arguments, index: &index)
            default:
                throw LocalWebSettingsError.invalidArgument(argument)
            }
            index += 1
        }

        guard (1...65_535).contains(port) else {
            throw LocalWebSettingsError.invalidPort(port)
        }

        let projectRoot = findProjectRoot(fileManager: fileManager)
        let resolvedWebRoot = (webRoot ?? projectRoot?.appendingPathComponent(
            "NavPlanner/Resources/Web",
            isDirectory: true
        ))?.standardizedFileURL
        guard let resolvedWebRoot,
              fileManager.fileExists(atPath: resolvedWebRoot.appendingPathComponent("map.html").path) else {
            throw LocalWebSettingsError.missingWebRoot(resolvedWebRoot?.path ?? "")
        }

        if databaseURL == nil, let projectRoot {
            let candidates = [
                projectRoot.appendingPathComponent("database/e_dfd_PMDG_release.s3db"),
                projectRoot.appendingPathComponent("NavPlanner/Resources/Database/navdata.sqlite")
            ]
            databaseURL = candidates.first { fileManager.fileExists(atPath: $0.path) }
        }
        if let databaseURL {
            let allowedExtensions = Set(["db", "s3db", "sqlite", "sqlite3"])
            guard fileManager.fileExists(atPath: databaseURL.path),
                  allowedExtensions.contains(databaseURL.pathExtension.lowercased()) else {
                throw LocalWebSettingsError.invalidDatabase(databaseURL.path)
            }
        }

        let resolvedDataRoot = (dataRoot ?? RuntimeConfiguration.defaultLocalWebDataRoot(
            environment: environment,
            fileManager: fileManager
        )).standardizedFileURL
        let resolvedToken = writeToken ?? UUID().uuidString.replacingOccurrences(of: "-", with: "")
        guard isValidToken(resolvedToken) else {
            throw LocalWebSettingsError.invalidToken
        }

        return LocalWebSettings(
            port: port,
            bindHost: bindHost,
            webRoot: resolvedWebRoot,
            dataRoot: resolvedDataRoot,
            bundledDatabaseURL: databaseURL?.standardizedFileURL,
            writeToken: resolvedToken
        )
    }

    private static func findProjectRoot(fileManager: FileManager) -> URL? {
        var candidate = URL(
            fileURLWithPath: fileManager.currentDirectoryPath,
            isDirectory: true
        ).standardizedFileURL
        for _ in 0..<8 {
            let manifest = candidate.appendingPathComponent("Package.swift")
            let webIndex = candidate.appendingPathComponent("NavPlanner/Resources/Web/map.html")
            if fileManager.fileExists(atPath: manifest.path),
               fileManager.fileExists(atPath: webIndex.path) {
                return candidate
            }
            let parent = candidate.deletingLastPathComponent()
            if parent.path == candidate.path {
                break
            }
            candidate = parent
        }
        return nil
    }

    private static func integerValue(
        after argument: String,
        arguments: [String],
        index: inout Int
    ) throws -> Int {
        let value = try stringValue(after: argument, arguments: arguments, index: &index)
        guard let parsed = Int(value) else {
            throw LocalWebSettingsError.invalidArgument("\(argument) \(value)")
        }
        return parsed
    }

    private static func pathValue(
        after argument: String,
        arguments: [String],
        index: inout Int
    ) throws -> URL {
        fileURL(try stringValue(after: argument, arguments: arguments, index: &index))
    }

    private static func stringValue(
        after argument: String,
        arguments: [String],
        index: inout Int
    ) throws -> String {
        let valueIndex = index + 1
        guard arguments.indices.contains(valueIndex), !arguments[valueIndex].isEmpty else {
            throw LocalWebSettingsError.missingValue(argument)
        }
        index = valueIndex
        return arguments[valueIndex]
    }

    private static func fileURL(_ path: String) -> URL {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    }

    private static func isValidToken(_ token: String) -> Bool {
        guard (16...128).contains(token.utf8.count) else { return false }
        return token.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 45, 46, 48...57, 65...90, 95, 97...122, 126:
                true
            default:
                false
            }
        }
    }

    private static func validatedBindHost(environment: [String: String]) throws -> String {
        let requested = environment["SIMNAV_BIND_HOST"] ?? "127.0.0.1"
        if requested == "127.0.0.1" {
            return requested
        }
        if requested == "0.0.0.0", environment["SIMNAV_CONTAINER"] == "1" {
            return requested
        }
        throw LocalWebSettingsError.invalidBindHost(requested)
    }
}

enum LocalWebSettingsError: LocalizedError {
    case invalidArgument(String)
    case missingValue(String)
    case invalidPort(Int)
    case missingWebRoot(String)
    case invalidDatabase(String)
    case invalidToken
    case invalidBindHost(String)

    var errorDescription: String? {
        switch self {
        case .invalidArgument(let argument):
            "Unknown or invalid Local Web argument: \(argument)"
        case .missingValue(let argument):
            "Missing value after \(argument)."
        case .invalidPort(let port):
            "Invalid Local Web port: \(port)."
        case .missingWebRoot(let path):
            "SimNav Web source was not found at: \(path.isEmpty ? "<unset>" : path)"
        case .invalidDatabase(let path):
            "Navigation database is missing or unsupported: \(path)"
        case .invalidToken:
            "SIMNAV_WRITE_TOKEN must be 16-128 URL-safe ASCII characters."
        case .invalidBindHost(let host):
            "Unsafe Local Web bind host: \(host). Only a marked container may bind 0.0.0.0."
        }
    }
}
