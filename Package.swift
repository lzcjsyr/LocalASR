// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "LocalASR",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "LocalASR", targets: ["LocalASR"])
    ],
    targets: [
        .executableTarget(
            name: "LocalASR",
            path: "Sources/LocalASR"
        ),
        .testTarget(
            name: "LocalASRTests",
            dependencies: ["LocalASR"],
            path: "Tests/LocalASRTests"
        )
    ]
)
