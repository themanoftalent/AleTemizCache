// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AleTemizCache",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "AleTemizCache", targets: ["AleTemizCache"]),
        .library(name: "TemizCacheCore", targets: ["TemizCacheCore"])
    ],
    targets: [
        .target(name: "TemizCacheCore"),
        .executableTarget(
            name: "AleTemizCache",
            dependencies: ["TemizCacheCore"]
        ),
        .testTarget(
            name: "TemizCacheCoreTests",
            dependencies: ["TemizCacheCore"]
        )
    ]
)
