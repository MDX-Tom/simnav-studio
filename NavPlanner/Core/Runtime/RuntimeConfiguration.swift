import Foundation

public struct RuntimeConfiguration: Sendable {
    public var dataRoot: URL
    public var bundledDatabaseURL: URL?
    public var webRoot: URL?
    public var performanceSubsystem: String

    public init(
        dataRoot: URL,
        bundledDatabaseURL: URL? = nil,
        webRoot: URL? = nil,
        performanceSubsystem: String = "com.mdxtom.simnavstudio.localweb"
    ) {
        self.dataRoot = dataRoot.standardizedFileURL
        self.bundledDatabaseURL = bundledDatabaseURL?.standardizedFileURL
        self.webRoot = webRoot?.standardizedFileURL
        self.performanceSubsystem = performanceSubsystem
    }

    public static func defaultLocalWebDataRoot(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> URL {
#if os(Windows)
        if let localAppData = environment["LOCALAPPDATA"], !localAppData.isEmpty {
            return URL(fileURLWithPath: localAppData, isDirectory: true)
                .appendingPathComponent("SimNav Studio Web", isDirectory: true)
        }
#elseif os(Linux)
        if let xdgDataHome = environment["XDG_DATA_HOME"], !xdgDataHome.isEmpty {
            return URL(fileURLWithPath: xdgDataHome, isDirectory: true)
                .appendingPathComponent("simnav-studio-web", isDirectory: true)
        }
        if let home = environment["HOME"], !home.isEmpty {
            return URL(fileURLWithPath: home, isDirectory: true)
                .appendingPathComponent(".local/share/simnav-studio-web", isDirectory: true)
        }
#else
        if let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first {
            return applicationSupport.appendingPathComponent("SimNav Studio Web", isDirectory: true)
        }
#endif
        return fileManager.temporaryDirectory
            .appendingPathComponent("simnav-studio-web", isDirectory: true)
    }
}
