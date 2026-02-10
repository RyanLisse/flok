// swift-tools-version: 6.0

import PackageDescription

let sharedSwiftSettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]

let package = Package(
    name: "Flok",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "flok", targets: ["Executable"]),
        .library(name: "FlokCore", targets: ["Core"]),
    ],
    dependencies: [
        .package(url: "https://github.com/steipete/Commander", from: "0.9.0"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.9.0"),
    ],
    targets: [
        // Core library — Graph client, auth, models (no CLI deps)
        .target(
            name: "Core",
            dependencies: [],
            path: "Sources/Core",
            swiftSettings: sharedSwiftSettings
        ),

        // CLI — Commander subcommands
        .target(
            name: "CLI",
            dependencies: [
                "Core",
                .product(name: "Commander", package: "Commander"),
            ],
            path: "Sources/CLI",
            swiftSettings: sharedSwiftSettings
        ),

        // MCP — Server + tools
        .target(
            name: "MCP",
            dependencies: [
                "Core",
                .product(name: "ModelContextProtocol", package: "swift-sdk"),
            ],
            path: "Sources/MCP",
            swiftSettings: sharedSwiftSettings
        ),

        // Executable — Main entry point
        .executableTarget(
            name: "Executable",
            dependencies: ["Core", "CLI", "MCP"],
            path: "Sources/Executable",
            swiftSettings: sharedSwiftSettings
        ),

        // Tests
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"],
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "MCPTests",
            dependencies: ["MCP", "Core"],
            swiftSettings: sharedSwiftSettings
        ),
    ]
)
