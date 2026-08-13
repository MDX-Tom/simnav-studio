#if !os(Windows)
import Foundation
import Hummingbird
import HTTPTypes
import SimNavCore

struct LocalWebHTTPServer: Sendable {
    let settings: LocalWebSettings
    let processor: LocalWebRequestProcessor

    var runtimeRouter: SimNavRuntimeRouter { processor.runtimeRouter }
    var webResourceStore: SimNavWebResourceStore { processor.webResourceStore }

    init(settings: LocalWebSettings, fr24BrowserFetcher: FR24BrowserFetching? = nil) {
        self.settings = settings
        self.processor = LocalWebRequestProcessor(
            settings: settings,
            fr24BrowserFetcher: fr24BrowserFetcher
        )
    }

    func buildRouter() -> Router<BasicRequestContext> {
        let router = Router()
        let methods: [HTTPRequest.Method] = [
            .get, .head, .post, .put, .patch, .delete, .options
        ]
        for method in methods {
            router.on("/", method: method) { request, _ in
                await respond(to: request)
            }
            router.on("/**", method: method) { request, _ in
                await respond(to: request)
            }
        }
        return router
    }

    private func respond(to request: Request) async -> Response {
        var transportRequest = makeTransportRequest(request)
        if let rejection = processor.headRejection(for: transportRequest) {
            return makeResponse(rejection)
        }

        switch processor.uploadDecision(for: transportRequest) {
        case .reject(let response):
            return makeResponse(response)
        case .upload(let plan):
            return await uploadedFileResponse(
                to: request,
                transportRequest: transportRequest,
                plan: plan
            )
        case .none:
            break
        }

        do {
            let buffer = try await request.body.collect(
                upTo: LocalWebRequestProcessor.maxRequestBodyBytes
            )
            transportRequest.body = Data(buffer.readableBytesView)
        } catch {
            return makeResponse(processor.uploadFailure(
                "Request body is too large.",
                status: 413,
                request: transportRequest
            ))
        }

        let result = await Task.detached(priority: .userInitiated) {
            processor.response(to: transportRequest)
        }.value
        return makeResponse(result)
    }

    private func uploadedFileResponse(
        to request: Request,
        transportRequest: LocalWebTransportRequest,
        plan: LocalWebUploadPlan
    ) async -> Response {
        do {
            try FileManager.default.createDirectory(
                at: plan.rootURL,
                withIntermediateDirectories: true
            )
            guard FileManager.default.createFile(atPath: plan.fileURL.path, contents: nil) else {
                throw CocoaError(.fileWriteUnknown)
            }
            defer { try? FileManager.default.removeItem(at: plan.rootURL) }

            let file = try FileHandle(forWritingTo: plan.fileURL)
            defer { try? file.close() }
            var receivedBytes = 0
            for try await buffer in request.body {
                receivedBytes += buffer.readableBytes
                guard receivedBytes <= plan.maximumBytes else {
                    return makeResponse(processor.uploadFailure(
                        "\(plan.uploadKind) upload exceeds the \(plan.maximumSizeDescription) limit.",
                        status: 413,
                        request: transportRequest
                    ))
                }
                try file.write(contentsOf: Data(buffer.readableBytesView))
            }
            try file.synchronize()
            guard receivedBytes > 0 else {
                return makeResponse(processor.uploadFailure(
                    "\(plan.uploadKind) upload is empty.",
                    status: 400,
                    request: transportRequest
                ))
            }

            var uploadedRequest = transportRequest
            uploadedRequest.bodyFileURL = plan.fileURL
            let result = await Task.detached(priority: .userInitiated) {
                processor.response(to: uploadedRequest)
            }.value
            return makeResponse(result)
        } catch {
            return makeResponse(processor.uploadFailure(
                "\(plan.uploadKind) upload failed: \(error.localizedDescription)",
                status: 400,
                request: transportRequest
            ))
        }
    }

    private func makeTransportRequest(_ request: Request) -> LocalWebTransportRequest {
        var headers: [String: String] = [:]
        for field in request.headers {
            let name = field.name.rawName
            if let existing = headers[name] {
                headers[name] = "\(existing), \(field.value)"
            } else {
                headers[name] = field.value
            }
        }
        return LocalWebTransportRequest(
            method: request.method.rawValue,
            target: request.uri.string,
            authority: request.head.authority,
            headers: headers
        )
    }

    private func makeResponse(_ source: RuntimeResponse) -> Response {
        var headers = HTTPFields()
        for (name, value) in source.headers.sorted(by: { $0.key < $1.key }) {
            guard let fieldName = HTTPField.Name(name) else { continue }
            headers[fieldName] = value
        }
        let responseBody: ResponseBody = if source.body.isEmpty {
            .init()
        } else {
            .init(byteBuffer: ByteBuffer(bytes: source.body))
        }
        return Response(
            status: .init(code: source.status),
            headers: headers,
            body: responseBody
        )
    }
}
#endif
