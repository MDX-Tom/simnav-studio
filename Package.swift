// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "SimNavStudio",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "SimNavCore", targets: ["SimNavCore"]),
        .executable(name: "simnav-local-web", targets: ["SimNavLocalWeb"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/hummingbird-project/hummingbird.git",
            exact: "2.22.0"
        ),
        .package(
            url: "https://github.com/apple/swift-nio.git",
            exact: "2.101.3"
        )
    ],
    targets: [
        .systemLibrary(
            name: "CSQLite",
            path: "LocalWeb/Support/CSQLite",
            pkgConfig: "sqlite3",
            providers: [
                .apt(["libsqlite3-dev"]),
                .brew(["sqlite3"])
            ]
        ),
        .target(
            name: "SimNavCore",
            dependencies: [
                .target(
                    name: "CSQLite",
                    condition: .when(platforms: [.linux, .windows])
                )
            ],
            path: "NavPlanner/Core",
            exclude: ["WebBridge"]
        ),
        .executableTarget(
            name: "SimNavLocalWeb",
            dependencies: [
                "SimNavCore",
                .product(
                    name: "Hummingbird",
                    package: "hummingbird",
                    condition: .when(platforms: [.macOS, .linux])
                ),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOWebSocket", package: "swift-nio")
            ],
            path: "LocalWeb/Sources/SimNavLocalWeb"
        ),
        .testTarget(
            name: "SimNavCoreTests",
            dependencies: ["SimNavCore"],
            path: "LocalWeb/Tests/SimNavCoreTests",
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "SimNavLocalWebTests",
            dependencies: [
                "SimNavLocalWeb",
                .target(
                    name: "CSQLite",
                    condition: .when(platforms: [.linux, .windows])
                ),
                .product(
                    name: "HummingbirdTesting",
                    package: "hummingbird",
                    condition: .when(platforms: [.macOS, .linux])
                )
            ],
            path: "LocalWeb/Tests/SimNavLocalWebTests"
        )
    ]
)
