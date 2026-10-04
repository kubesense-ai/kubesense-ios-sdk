// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "TestUtilities",
    platforms: [
        .iOS(.v15),
        .tvOS(.v15),
        .macOS(.v12),
        .watchOS(.v9),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "TestUtilities",
            targets: ["TestUtilities"]
        ),
    ],
    dependencies: [
        .package(name: "Kubesense", path: ".."),
    ],
    targets: [
        .target(
            name: "TestUtilities",
            dependencies: [
                .product(name: "KubesenseCore", package: "Kubesense"),
                .product(name: "KubesenseRUM", package: "Kubesense"),
                .product(name: "KubesenseLogs",package: "Kubesense"),
                .product(name: "KubesenseTrace",package: "Kubesense"),
                .product(name: "KubesenseCrashReporting",package: "Kubesense"),
                .product(name: "KubesenseSessionReplay", package: "Kubesense"),
                .product(name: "KubesenseWebViewTracking",package: "Kubesense")
            ],
            path: ".",
            sources: ["Sources"],
            swiftSettings: [.define("SPM_BUILD")]
        ),
    ]
)
