// swift-tools-version: 6.0
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
    dependencies: [
        // NOTE: This explicit dependency is required for CLT-only (Command Line Tools)
        // local development. While Swift 6+ includes swift-testing in the full Xcode
        // toolchain, the CLT-only environment needs the explicit package dependency.
        // The deprecation warnings about "Swift Testing is now included in the
        // Swift 6 toolchain" can be safely ignored in this configuration.
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "0.9.0")
    ],
    targets: [
        .target(
            name: "PaperWMCore",
            path: "Sources/PaperWMCore"
        ),

        .target(
            name: "PaperWMMacAdapters",
            dependencies: ["PaperWMCore"],
            path: "Sources/PaperWMMacAdapters"
        ),

        .target(
            name: "PaperWMRuntime",
            dependencies: ["PaperWMCore"],
            path: "Sources/PaperWMRuntime"
        ),

        .executableTarget(
            name: "PaperWMApp",
            dependencies: ["PaperWMCore", "PaperWMMacAdapters", "PaperWMRuntime"],
            path: "Sources/PaperWMApp"
        ),

        .testTarget(
            name: "PaperWMCoreTests",
            dependencies: [
                "PaperWMCore",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests/PaperWMCoreTests",
            swiftSettings: [
                .unsafeFlags(["-suppress-warnings"])
            ]
        ),
        .testTarget(
            name: "PaperWMMacAdaptersTests",
            dependencies: [
                "PaperWMMacAdapters",
                "PaperWMCore",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests/PaperWMMacAdaptersTests"
        ),
        .testTarget(
            name: "PaperWMRuntimeTests",
            dependencies: [
                "PaperWMRuntime",
                "PaperWMCore",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests/PaperWMRuntimeTests"
        ),
    ]
)
