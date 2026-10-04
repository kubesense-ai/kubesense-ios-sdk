// swift-tools-version: 6.0
// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Kubesense addition to the fork of dd-sdk-ios, see docs/UPSTREAM_SYNC.md.

// swift-testing tests of the Kubesense customizations that run on macOS with the Command Line Tools only
// (no XCTest, no Xcode). Run with `tools/kubesense-sync/verify/run-runtime-tests.sh`.
import PackageDescription

let package = Package(
    name: "kubesense-runtime-tests",
    platforms: [.macOS("12.6")],
    dependencies: [.package(path: "../../../..")],
    targets: [
        .testTarget(
            name: "KubesenseRuntimeTests",
            dependencies: [
                .product(name: "KubesenseCore", package: "kubesense-ios-sdk"),
                .product(name: "KubesenseLogs", package: "kubesense-ios-sdk"),
                .product(name: "KubesenseTrace", package: "kubesense-ios-sdk"),
                .product(name: "KubesenseFlags", package: "kubesense-ios-sdk"),
            ]
        ),
    ]
)
