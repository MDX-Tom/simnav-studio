import Foundation
#if !os(Windows)
import Hummingbird
#endif

@main
struct SimNavLocalWebMain {
    static func main() async throws {
        let settings = try LocalWebSettings.load()
#if os(Windows)
        try await NIOHTTPServer(settings: settings).run()
#else
        if ProcessInfo.processInfo.environment["SIMNAV_HTTP_TRANSPORT"] == "nio" {
            try await NIOHTTPServer(settings: settings).run()
            return
        }
        let server = LocalWebHTTPServer(settings: settings)
        let app = Application(
            router: server.buildRouter(),
            configuration: .init(
                address: .hostname(settings.bindHost, port: settings.port)
            )
        )

        print("SimNav Studio Local Web: http://127.0.0.1:\(settings.port)")
        try await app.runService()
#endif
    }
}
