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
                "PaperWMCore"
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
                "PaperWMCore"
            ],
            path: "Tests/PaperWMMacAdaptersTests"
        ),
        .testTarget(
            name: "PaperWMRuntimeTests",
            dependencies: [
                "PaperWMRuntime",
                "PaperWMCore"
            ],
            path: "Tests/PaperWMRuntimeTests"
        ),
    ]
)
