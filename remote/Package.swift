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
    dependencies: [
        .package(path: "SharedModels"),
    ],
    targets: [
        .target(
            name: "remote",
            dependencies: ["SharedModels"],
            path: "remote"
        ),
        .testTarget(
            name: "remoteTests",
            dependencies: ["remote", "SharedModels"],
            path: "remoteTests"
        ),
    ]
)
