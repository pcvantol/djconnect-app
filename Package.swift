// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DJConnectApp",
    defaultLocalization: "en",
    platforms: [
        .iOS("26.0"),
        .macOS("26.0"),
        .watchOS("26.0")
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
            name: "DJConnectCore",
            resources: [
                .process("Resources")
            ]
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
