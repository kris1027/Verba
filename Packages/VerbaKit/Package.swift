// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "VerbaKit",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "Core", targets: ["Core"]),
        .library(name: "Persistence", targets: ["Persistence"]),
        .library(name: "ClaudeBridge", targets: ["ClaudeBridge"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "Features", targets: ["Features"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.12.0"),
        .package(url: "https://github.com/swiftlang/swift-subprocess", from: "1.0.2"),
    ],
    targets: [
        // Domain types, teaching rules, service protocols, AppPaths, Log. Foundation only.
        .target(name: "Core"),

        // GRDB: AppDatabase, migrations, repositories.
        .target(
            name: "Persistence",
            dependencies: [
                "Core",
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),

        // The only module that launches a process or builds a prompt.
        .target(
            name: "ClaudeBridge",
            dependencies: [
                "Core",
                .product(name: "Subprocess", package: "swift-subprocess"),
            ],
            // Versioned prompts: a changed prompt is a new file (`lesson-v2.*`), never an edit.
            resources: [.copy("Resources/Prompts")]
        ),

        // Tokens, base components, print path, and the debug Design Gallery.
        // Domain free: imports none of Core, Persistence, ClaudeBridge, GRDB, Subprocess.
        .target(
            name: "DesignSystem",
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),

        // SwiftUI views and @Observable models. Imports Core and DesignSystem, never Persistence or ClaudeBridge.
        .target(
            name: "Features",
            dependencies: ["Core", "DesignSystem"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),

        .testTarget(name: "CoreTests", dependencies: ["Core"]),
        .testTarget(
            name: "PersistenceTests",
            dependencies: [
                "Persistence",
                "Core",
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .testTarget(
            name: "ClaudeBridgeTests",
            dependencies: [
                "ClaudeBridge",
                "Core",
            ]
        ),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"]),
        .testTarget(name: "FeaturesTests", dependencies: ["Features", "Core"]),
    ],
    swiftLanguageModes: [.v6]
)
