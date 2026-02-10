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
        .package(url: "https://github.com/steipete/Commander", from: "0.2.0"),
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

        // FlokMCP — Server + tools (renamed to avoid conflict with swift-sdk's MCP target)
        .target(
            name: "FlokMCP",
            dependencies: [
                "Core",
                .product(name: "MCP", package: "swift-sdk"),
            ],
            path: "Sources/MCP",
            swiftSettings: sharedSwiftSettings
        ),

        // Executable — Main entry point
        .executableTarget(
            name: "Executable",
            dependencies: ["Core", "CLI", "FlokMCP"],
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
            name: "FlokMCPTests",
            dependencies: ["FlokMCP", "Core"],
            path: "Tests/MCPTests",
            swiftSettings: sharedSwiftSettings
        ),
    ]
)
