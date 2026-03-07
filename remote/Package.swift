// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "remote",
    platforms: [
        .iOS(.v26)
    ],
    products: [
        .library(
            name: "remote",
            targets: ["remote"]
        ),
    ],
    targets: [
        .target(
            name: "remote",
            path: "remote"
        ),
        .testTarget(
            name: "remoteTests",
            dependencies: ["remote"],
            path: "remoteTests"
        ),
    ]
)
