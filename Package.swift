// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "LocalOverthinkerMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "LocalOverthinkerMac",
            targets: ["LocalOverthinkerMac"]
        )
    ],
    targets: [
        .executableTarget(
            name: "LocalOverthinkerMac",
            path: "Sources/LocalOverthinkerMac"
        )
    ]
)
