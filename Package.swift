// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PaperWM",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "PaperWMApp", targets: ["PaperWMApp"]),
        .library(name: "PaperWMCore", targets: ["PaperWMCore"]),
        .library(name: "PaperWMMacAdapters", targets: ["PaperWMMacAdapters"]),
        .library(name: "PaperWMRuntime", targets: ["PaperWMRuntime"]),
    ],
    targets: [
        // MARK: Core — pure data types and service protocols; no macOS framework imports.
        .target(
            name: "PaperWMCore",
            path: "Sources/PaperWMCore"
        ),

        // MARK: Mac Adapters — AX / display / workspace adapter stubs. Depends on Core.
        .target(
            name: "PaperWMMacAdapters",
            dependencies: ["PaperWMCore"],
            path: "Sources/PaperWMMacAdapters"
        ),

        // MARK: Runtime — domain service stubs. Depends on Core.
        .target(
            name: "PaperWMRuntime",
            dependencies: ["PaperWMCore"],
            path: "Sources/PaperWMRuntime"
        ),

        // MARK: App — menu-bar executable shell. Depends on all library targets.
        .executableTarget(
            name: "PaperWMApp",
            dependencies: ["PaperWMCore", "PaperWMMacAdapters", "PaperWMRuntime"],
            path: "Sources/PaperWMApp"
        ),

        // MARK: Test targets
        .testTarget(
            name: "PaperWMCoreTests",
            dependencies: ["PaperWMCore"],
            path: "Tests/PaperWMCoreTests"
        ),
        .testTarget(
            name: "PaperWMMacAdaptersTests",
            dependencies: ["PaperWMMacAdapters"],
            path: "Tests/PaperWMMacAdaptersTests"
        ),
        .testTarget(
            name: "PaperWMRuntimeTests",
            dependencies: ["PaperWMRuntime"],
            path: "Tests/PaperWMRuntimeTests"
        ),
    ]
)
