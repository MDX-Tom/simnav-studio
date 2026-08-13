import Foundation
import NIOCore
import NIOHTTP1
import NIOPosix
import SimNavCore

struct NIOHTTPServer: Sendable {
    let settings: LocalWebSettings
    let processor: LocalWebRequestProcessor

    init(settings: LocalWebSettings) {
        self.settings = settings
        self.processor = LocalWebRequestProcessor(settings: settings)
    }

    func run() async throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(
            numberOfThreads: max(1, System.coreCount)
        )
        let workerPool = NIOThreadPool(numberOfThreads: max(2, System.coreCount / 2))
        workerPool.start()

        do {
            let bootstrap = ServerBootstrap(group: eventLoopGroup)
                .serverChannelOption(ChannelOptions.backlog, value: 256)
                .serverChannelOption(
                    ChannelOptions.socketOption(.so_reuseaddr),
                    value: 1
                )
                .childChannelInitializer { channel in
                    channel.pipeline.configureHTTPServerPipeline(
                        withErrorHandling: true
                    ).flatMap {
                        channel.pipeline.addHandler(NIOLocalWebHandler(
                            processor: processor,
                            workerPool: workerPool
                        ))
                    }
                }
                .childChannelOption(
                    ChannelOptions.socketOption(.so_reuseaddr),
                    value: 1
                )
                .childChannelOption(ChannelOptions.tcpOption(.tcp_nodelay), value: 1)

            let channel = try await bootstrap.bind(
                host: settings.bindHost,
                port: settings.port
            ).get()
            print("SimNav Studio Local Web (SwiftNIO): http://127.0.0.1:\(settings.port)")
            try await channel.closeFuture.get()
        } catch {
            try? await workerPool.shutdownGracefully()
            try? await eventLoopGroup.shutdownGracefully()
            throw error
        }

        try await workerPool.shutdownGracefully()
        try await eventLoopGroup.shutdownGracefully()
    }
}

private final class NIOLocalWebHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private struct RequestState {
        var version: HTTPVersion
        var request: LocalWebTransportRequest
        var response: RuntimeResponse?
        var bodyBuffer: ByteBuffer
        var uploadPlan: LocalWebUploadPlan?
        var uploadFile: FileHandle?
        var receivedBytes = 0
    }

    private let processor: LocalWebRequestProcessor
    private let workerPool: NIOThreadPool
    private var state: RequestState?

    init(processor: LocalWebRequestProcessor, workerPool: NIOThreadPool) {
        self.processor = processor
        self.workerPool = workerPool
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        switch unwrapInboundIn(data) {
        case .head(let head):
            receiveHead(head, context: context)
        case .body(var buffer):
            receiveBody(&buffer)
        case .end:
            receiveEnd(context: context)
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        cleanupUpload()
        context.close(promise: nil)
    }

    func channelInactive(context: ChannelHandlerContext) {
        cleanupUpload()
        context.fireChannelInactive()
    }

    private func receiveHead(_ head: HTTPRequestHead, context: ChannelHandlerContext) {
        guard state == nil else {
            context.close(promise: nil)
            return
        }
        var headers: [String: String] = [:]
        for (name, value) in head.headers {
            if let existing = headers[name] {
                headers[name] = "\(existing), \(value)"
            } else {
                headers[name] = value
            }
        }
        let request = LocalWebTransportRequest(
            method: head.method.rawValue,
            target: head.uri,
            authority: head.headers.first(name: "Host"),
            headers: headers
        )
        var next = RequestState(
            version: head.version,
            request: request,
            response: processor.headRejection(for: request),
            bodyBuffer: context.channel.allocator.buffer(capacity: 0),
            uploadPlan: nil,
            uploadFile: nil
        )
        guard next.response == nil else {
            state = next
            return
        }

        switch processor.uploadDecision(for: request) {
        case .none:
            break
        case .reject(let response):
            next.response = response
        case .upload(let plan):
            do {
                try FileManager.default.createDirectory(
                    at: plan.rootURL,
                    withIntermediateDirectories: true
                )
                guard FileManager.default.createFile(atPath: plan.fileURL.path, contents: nil) else {
                    throw CocoaError(.fileWriteUnknown)
                }
                next.uploadPlan = plan
                next.uploadFile = try FileHandle(forWritingTo: plan.fileURL)
            } catch {
                next.response = processor.uploadFailure(
                    "\(plan.uploadKind) upload failed: \(error.localizedDescription)",
                    status: 400,
                    request: request
                )
            }
        }
        state = next
    }

    private func receiveBody(_ buffer: inout ByteBuffer) {
        guard var current = state, current.response == nil else { return }
        current.receivedBytes += buffer.readableBytes

        if let plan = current.uploadPlan {
            guard current.receivedBytes <= plan.maximumBytes else {
                current.response = processor.uploadFailure(
                    "\(plan.uploadKind) upload exceeds the \(plan.maximumSizeDescription) limit.",
                    status: 413,
                    request: current.request
                )
                state = current
                return
            }
            do {
                try current.uploadFile?.write(contentsOf: Data(buffer.readableBytesView))
            } catch {
                current.response = processor.uploadFailure(
                    "\(plan.uploadKind) upload failed: \(error.localizedDescription)",
                    status: 400,
                    request: current.request
                )
            }
        } else if current.receivedBytes <= LocalWebRequestProcessor.maxRequestBodyBytes {
            current.bodyBuffer.writeBuffer(&buffer)
        } else {
            current.response = processor.uploadFailure(
                "Request body is too large.",
                status: 413,
                request: current.request
            )
        }
        state = current
    }

    private func receiveEnd(context: ChannelHandlerContext) {
        guard var current = state else {
            context.close(promise: nil)
            return
        }
        state = nil

        if let plan = current.uploadPlan {
            do {
                try current.uploadFile?.synchronize()
                try current.uploadFile?.close()
                current.uploadFile = nil
                if current.response == nil, current.receivedBytes == 0 {
                    current.response = processor.uploadFailure(
                        "\(plan.uploadKind) upload is empty.",
                        status: 400,
                        request: current.request
                    )
                }
            } catch {
                current.response = processor.uploadFailure(
                    "\(plan.uploadKind) upload failed: \(error.localizedDescription)",
                    status: 400,
                    request: current.request
                )
            }
        }

        if let response = current.response {
            cleanupUpload(current)
            write(response, version: current.version, context: context)
            return
        }

        current.request.body = Data(current.bodyBuffer.readableBytesView)
        current.request.bodyFileURL = current.uploadPlan?.fileURL
        let request = current.request
        let version = current.version
        let uploadRoot = current.uploadPlan?.rootURL
        workerPool.runIfActive(eventLoop: context.eventLoop) {
            self.processor.response(to: request)
        }.whenComplete { result in
            if let uploadRoot {
                try? FileManager.default.removeItem(at: uploadRoot)
            }
            switch result {
            case .success(let response):
                self.write(response, version: version, context: context)
            case .failure(let error):
                let response = self.processor.uploadFailure(
                    "Local Web request failed: \(error.localizedDescription)",
                    status: 500,
                    request: request
                )
                self.write(response, version: version, context: context)
            }
        }
    }

    private func write(
        _ response: RuntimeResponse,
        version: HTTPVersion,
        context: ChannelHandlerContext
    ) {
        var headers = HTTPHeaders()
        for (name, value) in response.headers.sorted(by: { $0.key < $1.key }) {
            headers.replaceOrAdd(name: name, value: value)
        }
        if !headers.contains(name: "Content-Length") {
            headers.replaceOrAdd(name: "Content-Length", value: String(response.body.count))
        }
        headers.replaceOrAdd(name: "Connection", value: "close")
        let responseHead = HTTPResponseHead(
            version: version,
            status: HTTPResponseStatus(statusCode: response.status),
            headers: headers
        )
        context.write(wrapOutboundOut(.head(responseHead)), promise: nil)
        if !response.body.isEmpty {
            let buffer = context.channel.allocator.buffer(bytes: response.body)
            context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        }
        context.writeAndFlush(wrapOutboundOut(.end(nil))).flatMap {
            context.close()
        }.whenFailure { _ in
            context.close(promise: nil)
        }
    }

    private func cleanupUpload(_ requestState: RequestState? = nil) {
        var current = requestState ?? state
        try? current?.uploadFile?.close()
        if let root = current?.uploadPlan?.rootURL {
            try? FileManager.default.removeItem(at: root)
        }
        current?.uploadFile = nil
        if requestState == nil {
            state = nil
        }
    }
}
