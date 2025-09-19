// swift-tools-version: 5.5

import PackageDescription

let package = Package(
    name: "CBORCla",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
        .tvOS(.v14),
        .watchOS(.v7)
    ],
    products: [
        .library(
            name: "CBORCla",
            targets: ["CBORCla"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "CBORCla",
            dependencies: [],
            path: "Sources/CBORCla"
        ),
        .testTarget(
            name: "CBORClaTests",
            dependencies: ["CBORCla"],
            path: "Tests/CBORClaTests"
        ),
    ]
)