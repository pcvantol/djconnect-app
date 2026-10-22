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
    dependencies: [
        .package(url: "https://github.com/airsidemobile/JOSESwift.git", revision: "c2664a902e75c0426a1d43132bd4babc6fd173d3")
    ],
    targets: [
        .target(
            name: "DJConnectCore",
            dependencies: [.product(name: "JOSESwift", package: "JOSESwift")],
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "DJConnectUI",
            dependencies: ["DJConnectCore"],
            resources: [.process("VibeScapeShaders")]
        ),
        .testTarget(
            name: "DJConnectCoreTests",
            dependencies: ["DJConnectCore", "DJConnectUI", .product(name: "JOSESwift", package: "JOSESwift")],
            resources: [
                .process("../Fixtures")
            ]
        )
    ]
)
