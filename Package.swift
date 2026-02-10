// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "OutlookCLI",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "OutlookCore", targets: ["OutlookCore"]),
        .executable(name: "outlook", targets: ["Executable"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.6.0"),
    ],
    targets: [
        .target(
            name: "OutlookCore",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
        .target(
            name: "OutlookCLI",
            dependencies: [
                "OutlookCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(
            name: "OutlookMCP",
            dependencies: [
                "OutlookCore",
            ]
        ),
        .executableTarget(
            name: "Executable",
            dependencies: ["OutlookCLI", "OutlookMCP"]
        ),
        .testTarget(name: "OutlookCoreTests", dependencies: ["OutlookCore"]),
        .testTarget(name: "OutlookCLITests", dependencies: ["OutlookCLI"]),
    ]
)
