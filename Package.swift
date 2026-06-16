// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DJConnectApp",
    platforms: [
        .iOS("26.0"),
        .macOS("26.0")
    ],
    products: [
        .library(
            name: "DJConnectCore",
            targets: ["DJConnectCore"]
        ),
        .library(
            name: "DJConnectUI",
            targets: ["DJConnectUI"]
        )
    ],
    targets: [
        .target(
            name: "DJConnectCore"
        ),
        .target(
            name: "DJConnectUI",
            dependencies: ["DJConnectCore"]
        ),
        .testTarget(
            name: "DJConnectCoreTests",
            dependencies: ["DJConnectCore", "DJConnectUI"]
        )
    ]
)
