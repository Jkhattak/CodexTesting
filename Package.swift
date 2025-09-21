// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "SuperProductivity",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "SuperProductivityCore",
            targets: ["SuperProductivityCore"]
        ),
        .executable(
            name: "superproductivity-cli",
            targets: ["superproductivity-cli"]
        )
    ],
    targets: [
        .target(
            name: "SuperProductivityCore",
            dependencies: []
        ),
        .executableTarget(
            name: "superproductivity-cli",
            dependencies: [
                "SuperProductivityCore"
            ]
        ),
        .testTarget(
            name: "SuperProductivityCoreTests",
            dependencies: ["SuperProductivityCore"]
        )
    ]
)
