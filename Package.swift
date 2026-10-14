// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TemizCache",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "TemizCache", targets: ["TemizCache"]),
        .library(name: "TemizCacheCore", targets: ["TemizCacheCore"])
    ],
    targets: [
        .target(name: "TemizCacheCore"),
        .executableTarget(
            name: "TemizCache",
            dependencies: ["TemizCacheCore"]
        ),
        .testTarget(
            name: "TemizCacheCoreTests",
            dependencies: ["TemizCacheCore"]
        )
    ]
)
