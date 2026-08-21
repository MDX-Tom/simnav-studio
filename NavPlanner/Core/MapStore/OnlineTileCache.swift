import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct OnlineTileProvider {
    let key: String
    let format: String
    let contentType: String
    let templates: [String]
    let maxZoom: Int

    func requestURLs(z: Int, x: Int, y: Int) -> [URL] {
        templates.compactMap { template in
            URL(string: template
                .replacingOccurrences(of: "{z}", with: String(z))
                .replacingOccurrences(of: "{x}", with: String(x))
                .replacingOccurrences(of: "{y}", with: String(y)))
        }
    }
}

final class SimNavOnlineTileCache: @unchecked Sendable {
    enum TileState {
        case hit(data: Data, contentType: String)
        case queued
        case pending
        case failed
    }

    enum RequestPriority: Int {
        case preview = 1
        case visible = 2

        var operationQueuePriority: Operation.QueuePriority {
            switch self {
            case .visible: .veryHigh
            case .preview: .high
            }
        }
    }

    private final class TileDownloadJob: @unchecked Sendable {
        let key: String
        let operation = BlockOperation()
        let sequence: UInt64
        var demandGeneration: UInt64
        var priority: RequestPriority

        private let taskLock = NSLock()
        private var activeTask: URLSessionTask?

        init(key: String, sequence: UInt64, demandGeneration: UInt64, priority: RequestPriority) {
            self.key = key
            self.sequence = sequence
            self.demandGeneration = demandGeneration
            self.priority = priority
            operation.queuePriority = priority.operationQueuePriority
        }

        func promote(to newPriority: RequestPriority) {
            guard newPriority.rawValue > priority.rawValue else { return }
            priority = newPriority
            operation.queuePriority = newPriority.operationQueuePriority
        }

        func installActiveTask(_ task: URLSessionTask) -> Bool {
            taskLock.simNavWithLock {
                guard !operation.isCancelled else { return false }
                activeTask = task
                return true
            }
        }

        func clearActiveTask(_ task: URLSessionTask) {
            taskLock.simNavWithLock {
                if activeTask === task {
                    activeTask = nil
                }
            }
        }

        func cancel() {
            operation.cancel()
            let task = taskLock.simNavWithLock { () -> URLSessionTask? in
                let task = activeTask
                activeTask = nil
                return task
            }
            task?.cancel()
        }
    }

    private struct TilePayload {
        let data: Data
        let contentType: String
    }

    private final class TileDownloadResult: @unchecked Sendable {
        private let lock = NSLock()
        private var data: Data?
        private var response: HTTPURLResponse?

        func store(data: Data?, response: URLResponse?) {
            lock.simNavWithLock {
                self.data = data
                self.response = response as? HTTPURLResponse
            }
        }

        func value() -> (Data?, HTTPURLResponse?) {
            lock.simNavWithLock { (data, response) }
        }
    }

    static let tileResponseWaitTimeout: TimeInterval = 2.4
    private static let requestTimeout: TimeInterval = 8
    private static let resourceTimeout: TimeInterval = 14
    private static let downloadWorkers = 8
    private static let downloadRetries = 1
    private static let retryDelay: TimeInterval = 0.35
    // Keep rapid pan/zoom bursts bounded below the UI regression threshold.
    // Overflow cancellation always prefers older/lower-priority work while the
    // current visible generation remains the shared cache's first concern.
    private static let maxPendingDownloads = 120
    private static let maxDownloadTasksPerSession = 48

    private let fileManager: FileManager
    private let rootDirectory: URL
    private let previousRootDirectories: [URL]
    private var session: URLSession
    private let downloadSessionConfiguration: URLSessionConfiguration
    private let sessionLock = NSLock()
    private var sessionTaskCount = 0
    private var sessionRotationCount = 0
    private let downloadQueue: OperationQueue
    private let lock = NSLock()
    private var pendingJobs: [String: TileDownloadJob] = [:]
    private var activeJobIDs = Set<ObjectIdentifier>()
    private var failedAtByKey: [String: Date] = [:]
    private var latestDemandGeneration: UInt64 = 0
    private var nextJobSequence: UInt64 = 0
    private var peakPendingCount = 0
    private var cancelledStaleCount = 0
    private var cancelledOverflowCount = 0
    private var successfulDownloadCount = 0
    private let failureCooldown: TimeInterval = 8

    static let providers: [String: OnlineTileProvider] = [
        "arcgis": OnlineTileProvider(
            key: "arcgis",
            format: "jpg",
            contentType: "image/jpeg",
            templates: [
                "https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}",
                "https://services.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}"
            ],
            maxZoom: 20
        ),
        "arcgis-dark": OnlineTileProvider(
            key: "arcgis-dark",
            format: "jpg",
            contentType: "image/jpeg",
            templates: [
                "https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}",
                "https://services.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}"
            ],
            maxZoom: 20
        ),
        "openstreetmap": OnlineTileProvider(
            key: "openstreetmap",
            format: "png",
            contentType: "image/png",
            templates: ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"],
            maxZoom: 19
        ),
        "opentopomap": OnlineTileProvider(
            key: "opentopomap",
            format: "png",
            contentType: "image/png",
            templates: [
                "https://a.tile.opentopomap.org/{z}/{x}/{y}.png",
                "https://b.tile.opentopomap.org/{z}/{x}/{y}.png",
                "https://c.tile.opentopomap.org/{z}/{x}/{y}.png"
            ],
            maxZoom: 17
        ),
        "google": OnlineTileProvider(
            key: "google",
            format: "jpg",
            contentType: "image/jpeg",
            templates: [
                "https://mt0.google.com/vt/lyrs=p&x={x}&y={y}&z={z}&hl=en&gl=US",
                "https://mt1.google.com/vt/lyrs=p&x={x}&y={y}&z={z}&hl=en&gl=US",
                "https://mt2.google.com/vt/lyrs=p&x={x}&y={y}&z={z}&hl=en&gl=US",
                "https://mt3.google.com/vt/lyrs=p&x={x}&y={y}&z={z}&hl=en&gl=US"
            ],
            maxZoom: 20
        ),
        "google_terrain": OnlineTileProvider(
            key: "google_terrain",
            format: "jpg",
            contentType: "image/jpeg",
            templates: [
                "https://mt0.google.com/vt/lyrs=p&x={x}&y={y}&z={z}&hl=en&gl=US",
                "https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}",
                "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                "https://a.tile.opentopomap.org/{z}/{x}/{y}.png",
                "https://b.tile.opentopomap.org/{z}/{x}/{y}.png",
                "https://c.tile.opentopomap.org/{z}/{x}/{y}.png",
                "https://mt1.google.com/vt/lyrs=p&x={x}&y={y}&z={z}&hl=en&gl=US",
                "https://mt2.google.com/vt/lyrs=p&x={x}&y={y}&z={z}&hl=en&gl=US",
                "https://mt3.google.com/vt/lyrs=p&x={x}&y={y}&z={z}&hl=en&gl=US"
            ],
            maxZoom: 20
        ),
        "terrain_terrarium": OnlineTileProvider(
            key: "terrain_terrarium",
            format: "png",
            contentType: "image/png",
            templates: [
                "https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png",
                "https://elevation-tiles-prod.s3.amazonaws.com/terrarium/{z}/{x}/{y}.png"
            ],
            maxZoom: 13
        )
    ]

    init(
        fileManager: FileManager = .default,
        rootDirectory: URL? = nil,
        sessionConfiguration: URLSessionConfiguration? = nil
    ) {
        self.fileManager = fileManager
        if let rootDirectory {
            self.rootDirectory = rootDirectory.standardizedFileURL
            self.previousRootDirectories = []
        } else {
            let cacheRoot = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            let navRoot = cacheRoot.appendingPathComponent("NavPlanner", isDirectory: true)
            self.rootDirectory = navRoot.appendingPathComponent("MapCacheV3", isDirectory: true)
            self.previousRootDirectories = [
                navRoot.appendingPathComponent("MapCacheV2", isDirectory: true),
                navRoot.appendingPathComponent("MapCache", isDirectory: true)
            ]
        }
        let configuration = sessionConfiguration ?? Self.sessionConfiguration()
        self.downloadSessionConfiguration = configuration
        self.session = URLSession(configuration: configuration)

        let queue = OperationQueue()
        queue.name = "com.mdxtom.simnavstudio.online-map-cache"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = Self.downloadWorkers
        self.downloadQueue = queue
        try? fileManager.createDirectory(at: self.rootDirectory, withIntermediateDirectories: true)
    }

    func tile(
        providerKey: String,
        z: Int,
        x: Int,
        y: Int,
        waitForDownload: TimeInterval = 0,
        demandGeneration: UInt64 = 0,
        priority: RequestPriority = .visible,
        shouldCancel: () -> Bool = { false }
    ) -> TileState {
        guard let provider = Self.providers[providerKey],
              z >= 0, z <= provider.maxZoom, x >= 0, y >= 0 else {
            return .failed
        }
        let localURL = tileFileURL(provider: provider, z: z, x: x, y: y)
        if let payload = cachedTilePayload(provider: provider, localURL: localURL, z: z, x: x, y: y) {
            return .hit(data: payload.data, contentType: payload.contentType)
        }
        let remoteURLs = provider.requestURLs(z: z, x: x, y: y)
        guard !remoteURLs.isEmpty else { return .failed }

        let key = cacheKey(provider: provider, z: z, x: x, y: y)
        var jobsToCancel: [TileDownloadJob] = []
        var jobToEnqueue: TileDownloadJob?
        let immediateState = lock.simNavWithLock { () -> TileState? in
            if demandGeneration > 0 {
                guard demandGeneration >= latestDemandGeneration else { return .failed }
                if demandGeneration > latestDemandGeneration {
                    latestDemandGeneration = demandGeneration
                    let stale = pendingJobs.values.filter {
                        $0.demandGeneration > 0 && $0.demandGeneration < demandGeneration
                    }
                    for job in stale where pendingJobs[job.key] === job {
                        pendingJobs.removeValue(forKey: job.key)
                    }
                    cancelledStaleCount += stale.count
                    jobsToCancel.append(contentsOf: stale)
                }
            }
            if let pending = pendingJobs[key] {
                pending.demandGeneration = max(pending.demandGeneration, demandGeneration)
                pending.promote(to: priority)
                return .pending
            }
            if let failedAt = failedAtByKey[key] {
                guard Date().timeIntervalSince(failedAt) >= failureCooldown else { return .failed }
                failedAtByKey.removeValue(forKey: key)
            }

            nextJobSequence &+= 1
            let job = TileDownloadJob(
                key: key,
                sequence: nextJobSequence,
                demandGeneration: demandGeneration,
                priority: priority
            )
            pendingJobs[key] = job
            jobToEnqueue = job
            peakPendingCount = max(peakPendingCount, pendingJobs.count)
            let overflow = max(0, pendingJobs.count - Self.maxPendingDownloads)
            if overflow > 0 {
                let victims = pendingJobs.values
                    .filter { $0 !== job && !$0.operation.isExecuting }
                    .sorted {
                        $0.priority.rawValue == $1.priority.rawValue
                            ? $0.sequence < $1.sequence
                            : $0.priority.rawValue < $1.priority.rawValue
                    }
                    .prefix(overflow)
                for victim in victims where pendingJobs[victim.key] === victim {
                    pendingJobs.removeValue(forKey: victim.key)
                    jobsToCancel.append(victim)
                    cancelledOverflowCount += 1
                }
            }
            return nil
        }
        jobsToCancel.forEach { $0.cancel() }

        if let immediateState {
            if case .pending = immediateState,
               waitForDownload > 0,
               let payload = waitForCachedTile(
                provider: provider,
                localURL: localURL,
                timeout: waitForDownload,
                shouldCancel: shouldCancel
               ) {
                return .hit(data: payload.data, contentType: payload.contentType)
            }
            return immediateState
        }

        if let jobToEnqueue {
            downloadTile(provider: provider, remoteURLs: remoteURLs, localURL: localURL, job: jobToEnqueue)
        }
        if waitForDownload > 0,
           let payload = waitForCachedTile(
            provider: provider,
            localURL: localURL,
            timeout: waitForDownload,
            shouldCancel: shouldCancel
           ) {
            return .hit(data: payload.data, contentType: payload.contentType)
        }
        return .queued
    }

    func cachedTile(providerKey: String, z: Int, x: Int, y: Int) -> TileState {
        guard let provider = Self.providers[providerKey],
              z >= 0, z <= provider.maxZoom, x >= 0, y >= 0,
              let payload = cachedTilePayload(
                provider: provider,
                localURL: tileFileURL(provider: provider, z: z, x: x, y: y),
                z: z,
                x: x,
                y: y
              ) else {
            return .failed
        }
        return .hit(data: payload.data, contentType: payload.contentType)
    }

    func statusPayload() -> [String: Any] {
        let usage = diskUsage()
        let sessionRuntime = sessionLock.simNavWithLock {
            (taskCount: sessionTaskCount, rotationCount: sessionRotationCount)
        }
        let runtime = lock.simNavWithLock { () -> [String: Any] in
            let activeCount = pendingJobs.values.reduce(into: 0) { count, job in
                if activeJobIDs.contains(ObjectIdentifier(job)) { count += 1 }
            }
            return [
                "pending_count": pendingJobs.count,
                "active_count": activeCount,
                "queued_count": max(0, pendingJobs.count - activeCount),
                "failed_count": failedAtByKey.count,
                "latest_demand_generation": latestDemandGeneration,
                "peak_pending_count": peakPendingCount,
                "cancelled_stale_count": cancelledStaleCount,
                "cancelled_overflow_count": cancelledOverflowCount,
                "successful_download_count": successfulDownloadCount
            ]
        }
        return [
            "root": rootDirectory.path,
            "size_bytes": usage.bytes,
            "file_count": usage.files,
            "providers": Self.providers.values.sorted { $0.key < $1.key }.map {
                ["key": $0.key, "format": $0.format, "max_zoom": $0.maxZoom]
            },
            "pending_count": runtime["pending_count"] ?? 0,
            "active_count": runtime["active_count"] ?? 0,
            "queued_count": runtime["queued_count"] ?? 0,
            "failed_count": runtime["failed_count"] ?? 0,
            "latest_demand_generation": runtime["latest_demand_generation"] ?? 0,
            "peak_pending_count": runtime["peak_pending_count"] ?? 0,
            "cancelled_stale_count": runtime["cancelled_stale_count"] ?? 0,
            "cancelled_overflow_count": runtime["cancelled_overflow_count"] ?? 0,
            "successful_download_count": runtime["successful_download_count"] ?? 0,
            "queue_capacity": Self.maxPendingDownloads,
            "session_task_count": sessionRuntime.taskCount,
            "session_rotation_count": sessionRuntime.rotationCount,
            "session_task_capacity": Self.maxDownloadTasksPerSession,
            "message": "在线底图缓存状态已读取。"
        ]
    }

    func clearPayload() -> [String: Any] {
        let jobs = lock.simNavWithLock { () -> [TileDownloadJob] in
            let jobs = Array(pendingJobs.values)
            pendingJobs.removeAll()
            failedAtByKey.removeAll()
            activeJobIDs.removeAll()
            latestDemandGeneration = 0
            peakPendingCount = 0
            cancelledStaleCount = 0
            cancelledOverflowCount = 0
            successfulDownloadCount = 0
            return jobs
        }
        jobs.forEach { $0.cancel() }
        downloadQueue.cancelAllOperations()
        for directory in [rootDirectory] + previousRootDirectories {
            for item in (try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )) ?? [] {
                try? fileManager.removeItem(at: item)
            }
        }
        try? fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        var payload = statusPayload()
        payload["message"] = "已清理在线地图缓存。"
        return payload
    }

    private func cachedTilePayload(provider: OnlineTileProvider, localURL: URL) -> TilePayload? {
        guard let data = try? Data(contentsOf: localURL), !data.isEmpty else { return nil }
        guard let payload = cacheTilePayload(from: data, provider: provider) else {
            try? fileManager.removeItem(at: localURL)
            return nil
        }
        return payload
    }

    private func cachedTilePayload(
        provider: OnlineTileProvider,
        localURL: URL,
        z: Int,
        x: Int,
        y: Int
    ) -> TilePayload? {
        if let payload = cachedTilePayload(provider: provider, localURL: localURL) {
            return payload
        }
        guard let legacyURL = legacyNormalizedTileFileURL(provider: provider, z: z, x: x, y: y),
              legacyURL != localURL else {
            return nil
        }
        return cachedTilePayload(provider: provider, localURL: legacyURL)
    }

    private func waitForCachedTile(
        provider: OnlineTileProvider,
        localURL: URL,
        timeout: TimeInterval,
        shouldCancel: () -> Bool
    ) -> TilePayload? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if shouldCancel() { return nil }
            Thread.sleep(forTimeInterval: 0.08)
            if let payload = cachedTilePayload(provider: provider, localURL: localURL) {
                return payload
            }
        }
        return nil
    }

    private func downloadTile(
        provider: OnlineTileProvider,
        remoteURLs: [URL],
        localURL: URL,
        job: TileDownloadJob
    ) {
        job.operation.addExecutionBlock { [weak self, weak job] in
            guard let self, let job, !job.operation.isCancelled else { return }
            let jobID = ObjectIdentifier(job)
            self.lock.simNavWithLock { _ = self.activeJobIDs.insert(jobID) }
            defer {
                self.lock.simNavWithLock {
                    self.activeJobIDs.remove(jobID)
                    if self.pendingJobs[job.key] === job {
                        self.pendingJobs.removeValue(forKey: job.key)
                    }
                }
            }

            for retry in 0...Self.downloadRetries {
                guard !job.operation.isCancelled else { return }
                for remoteURL in remoteURLs {
                    guard !job.operation.isCancelled else { return }
                    guard let payload = self.downloadTilePayload(
                        provider: provider,
                        remoteURL: remoteURL,
                        job: job
                    ) else { continue }
                    guard !job.operation.isCancelled else { return }
                    if self.writeCacheData(payload.data, to: localURL) {
                        self.lock.simNavWithLock {
                            self.failedAtByKey.removeValue(forKey: job.key)
                            self.successfulDownloadCount += 1
                        }
                        return
                    }
                }
                if retry < Self.downloadRetries {
                    Thread.sleep(forTimeInterval: Self.retryDelay * Double(retry + 1))
                }
            }
            guard !job.operation.isCancelled else { return }
            self.lock.simNavWithLock { self.failedAtByKey[job.key] = Date() }
        }
        downloadQueue.addOperation(job.operation)
    }

    private func downloadTilePayload(
        provider: OnlineTileProvider,
        remoteURL: URL,
        job: TileDownloadJob
    ) -> TilePayload? {
        let result = TileDownloadResult()
        let semaphore = DispatchSemaphore(value: 0)
        let task = makeDownloadTask(for: tileRequest(for: remoteURL)) { data, response, _ in
            result.store(data: data, response: response)
            semaphore.signal()
        }
        task.priority = URLSessionTask.highPriority
        guard job.installActiveTask(task) else {
            task.cancel()
            return nil
        }
        task.resume()
        guard semaphore.wait(timeout: .now() + Self.resourceTimeout + 1) == .success else {
            task.cancel()
            job.clearActiveTask(task)
            return nil
        }
        job.clearActiveTask(task)
        guard !job.operation.isCancelled else { return nil }
        let value = result.value()
        guard let response = value.1,
              (200..<300).contains(response.statusCode),
              let data = value.0 else { return nil }
        return cacheTilePayload(from: data, provider: provider)
    }

    private static func sessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = resourceTimeout
        configuration.httpMaximumConnectionsPerHost = downloadWorkers
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        return configuration
    }

    private func makeDownloadTask(
        for request: URLRequest,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        var previousSession: URLSession?
        let task = sessionLock.simNavWithLock { () -> URLSessionDataTask in
            if sessionTaskCount >= Self.maxDownloadTasksPerSession {
                previousSession = session
                session = URLSession(configuration: downloadSessionConfiguration)
                sessionTaskCount = 0
                sessionRotationCount += 1
            }
            sessionTaskCount += 1
            return session.dataTask(with: request, completionHandler: completionHandler)
        }
        previousSession?.finishTasksAndInvalidate()
        return task
    }

    private func tileRequest(for remoteURL: URL) -> URLRequest {
        var request = URLRequest(url: remoteURL)
        request.timeoutInterval = Self.requestTimeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(
            "Mozilla/5.0 AppleWebKit/605.1.15 Safari/605.1.15 SimNav-Studio/1.0",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("image/jpeg,image/png,image/*;q=0.8,*/*;q=0.5", forHTTPHeaderField: "Accept")
        return request
    }

    private func writeCacheData(_ data: Data, to localURL: URL) -> Bool {
        do {
            try fileManager.createDirectory(
                at: localURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let temporary = localURL.deletingLastPathComponent()
                .appendingPathComponent(".\(localURL.lastPathComponent).\(UUID().uuidString).tmp")
            try data.write(to: temporary, options: [.atomic])
            try? fileManager.removeItem(at: localURL)
            try fileManager.moveItem(at: temporary, to: localURL)
            return true
        } catch {
            return false
        }
    }

    private func cacheTilePayload(from data: Data, provider: OnlineTileProvider) -> TilePayload? {
        guard isValidTileData(data, provider: provider) else { return nil }
        return TilePayload(data: data, contentType: contentType(for: data) ?? provider.contentType)
    }

    private func isValidTileData(_ data: Data, provider: OnlineTileProvider) -> Bool {
        guard !data.isEmpty else { return false }
        switch provider.format {
        case "jpg", "jpeg": return isJPEG(data) || isPNG(data)
        case "png": return isPNG(data)
        default: return true
        }
    }

    private func contentType(for data: Data) -> String? {
        if isJPEG(data) { return "image/jpeg" }
        if isPNG(data) { return "image/png" }
        return nil
    }

    private func isJPEG(_ data: Data) -> Bool {
        guard data.count >= 4, data.prefix(2).elementsEqual([0xff, 0xd8]) else { return false }
        var index = data.count - 1
        while index > 2, [0x00, 0x0a, 0x0d, 0x20].contains(data[index]) {
            index -= 1
        }
        return index >= 3 && data[index - 1] == 0xff && data[index] == 0xd9
    }

    private func isPNG(_ data: Data) -> Bool {
        let signature: [UInt8] = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]
        let iend: [UInt8] = [0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82]
        return data.count >= 20
            && data.prefix(signature.count).elementsEqual(signature)
            && data.suffix(iend.count).elementsEqual(iend)
    }

    private func cacheKey(provider: OnlineTileProvider, z: Int, x: Int, y: Int) -> String {
        "\(provider.key)|\(z)|\(x)|\(y)"
    }

    private func tileFileURL(provider: OnlineTileProvider, z: Int, x: Int, y: Int) -> URL {
        rootDirectory
            .appendingPathComponent(provider.key, isDirectory: true)
            .appendingPathComponent(String(format: "z%02d", z), isDirectory: true)
            .appendingPathComponent(String(format: "%04x", x >> 8), isDirectory: true)
            .appendingPathComponent(
                "\(String(format: "%08x", x))_\(String(format: "%08x", y)).\(provider.format)"
            )
    }

    private func legacyNormalizedTileFileURL(
        provider: OnlineTileProvider,
        z: Int,
        x: Int,
        y: Int
    ) -> URL? {
        guard ["jpg", "jpeg"].contains(provider.format) else { return nil }
        return rootDirectory
            .appendingPathComponent(provider.key, isDirectory: true)
            .appendingPathComponent(String(format: "z%02d", z), isDirectory: true)
            .appendingPathComponent(String(format: "%04x", x >> 8), isDirectory: true)
            .appendingPathComponent(
                "\(String(format: "%08x", x))_\(String(format: "%08x", y)).png"
            )
    }

    private func diskUsage() -> (bytes: Int64, files: Int) {
        guard let enumerator = fileManager.enumerator(
            at: rootDirectory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return (0, 0) }
        var bytes: Int64 = 0
        var files = 0
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true else { continue }
            files += 1
            bytes += Int64(values.fileSize ?? 0)
        }
        return (bytes, files)
    }
}

private extension NSLock {
    func simNavWithLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
