// swift-tools-version: 6.2

import PackageDescription
import Foundation

let internalSwiftSettings: [SwiftSetting] = ProcessInfo.processInfo.environment["KUBESENSE_BENCHMARK"] != nil ?
    [.define("KUBESENSE_BENCHMARK")] : []

let package = Package(
    name: "Kubesense",
    platforms: [
        .iOS(.v15),
        .tvOS(.v15),
        .macOS("12.0"),
        .watchOS(.v9),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "KubesenseCore",
            targets: ["KubesenseCore"]
        ),
        .library(
            name: "KubesenseLogs",
            targets: ["KubesenseLogs"]
        ),
        .library(
            name: "KubesenseTrace",
            targets: ["KubesenseTrace"]
        ),
        .library(
            name: "KubesenseRUM",
            targets: ["KubesenseRUM"]
        ),
        .library(
            name: "KubesenseSessionReplay",
            targets: ["KubesenseSessionReplay"]
        ),
        .library(
            name: "KubesenseCrashReporting",
            targets: ["KubesenseCrashReporting"]
        ),
        .library(
            name: "KubesenseWebViewTracking",
            targets: ["KubesenseWebViewTracking"]
        ),
        .library(
            name: "KubesenseFlags",
            targets: ["KubesenseFlags"]
        ),
        .library(
            name: "KubesenseProfiling",
            targets: ["KubesenseProfiling"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/kstenerud/KSCrash.git", exact: "2.5.1"),
        .package(url: "https://github.com/open-telemetry/opentelemetry-swift-core", .upToNextMinor(from: "2.5.0")),
        .package(url: "https://github.com/DataDog/dd-sdk-swift-testing.git", .upToNextMinor(from: "2.7.11")),
    ],
    targets: [
        .target(
            name: "KubesenseCore",
            dependencies: [
                .target(name: "KubesenseInternal"),
                .target(name: "KubesensePrivate"),
            ],
            path: "KubesenseCore",
            sources: ["Sources"],
            resources: [
                .copy("Resources/PrivacyInfo.xcprivacy")
            ],
            swiftSettings: [.define("SPM_BUILD")] + internalSwiftSettings
        ),
        .target(
            name: "KubesensePrivate",
            path: "KubesenseCore/Private"
        ),

        .target(
            name: "KubesenseInternal",
            path: "KubesenseInternal/Sources",
            swiftSettings: internalSwiftSettings
        ),
        .testTarget(
            name: "KubesenseInternalTests",
            dependencies: [
                .target(name: "KubesenseInternal"),
                .target(name: "TestUtilities"),
                .product(name: "DatadogSDKTesting", package: "dd-sdk-swift-testing"),
            ],
            path: "KubesenseInternal/Tests"
        ),

        .target(
            name: "KubesenseLogs",
            dependencies: [
                .target(name: "KubesenseInternal"),
            ],
            path: "KubesenseLogs/Sources"
        ),
        .testTarget(
            name: "KubesenseLogsTests",
            dependencies: [
                .target(name: "KubesenseLogs"),
                .target(name: "TestUtilities"),
            ],
            path: "KubesenseLogs/Tests"
        ),

        .target(
            name: "KubesenseTrace",
            dependencies: [
                .target(name: "KubesenseInternal"),
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core")
            ],
            path: "KubesenseTrace/Sources",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "KubesenseTraceTests",
            dependencies: [
                .target(name: "KubesenseTrace"),
                .target(name: "TestUtilities"),
            ],
            path: "KubesenseTrace/Tests",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),

        .target(
            name: "KubesenseRUM",
            dependencies: [
                .target(name: "KubesenseInternal"),
                .target(name: "KubesenseRUMPrivate"),
            ],
            path: "KubesenseRUM",
            sources: ["Sources"],
            resources: [
                .copy("Resources/PrivacyInfo.xcprivacy")
            ],
            swiftSettings: [.define("SPM_BUILD")] + internalSwiftSettings
        ),
        .target(
            name: "KubesenseRUMPrivate",
            path: "KubesenseRUM/Private"
        ),
        .testTarget(
            name: "KubesenseRUMTests",
            dependencies: [
                .target(name: "KubesenseRUM"),
                .target(name: "TestUtilities"),
                .product(name: "DatadogSDKTesting", package: "dd-sdk-swift-testing"),
            ],
            path: "KubesenseRUM/Tests"
        ),

        .target(
            name: "KubesenseCrashReporting",
            dependencies: [
                .target(name: "KubesenseInternal"),
                .product(name: "Recording", package: "KSCrash"),
                .product(name: "Filters", package: "KSCrash")
            ],
            path: "KubesenseCrashReporting",
            sources: ["Sources"],
            resources: [
                .copy("Resources/PrivacyInfo.xcprivacy")
            ]
        ),
        .testTarget(
            name: "KubesenseCrashReportingTests",
            dependencies: [
                .target(name: "KubesenseCrashReporting"),
                .target(name: "TestUtilities"),
            ],
            path: "KubesenseCrashReporting/Tests"
        ),

        .target(
            name: "KubesenseWebViewTracking",
            dependencies: [
                .target(name: "KubesenseInternal"),
            ],
            path: "KubesenseWebViewTracking/Sources"
        ),
        .testTarget(
            name: "KubesenseWebViewTrackingTests",
            dependencies: [
                .target(name: "KubesenseWebViewTracking"),
                .target(name: "TestUtilities"),
            ],
            path: "KubesenseWebViewTracking/Tests"
        ),

        .target(
            name: "KubesenseSessionReplay",
            dependencies: ["KubesenseInternal"],
            path: "KubesenseSessionReplay/Sources"
        ),
        .testTarget(
            name: "KubesenseSessionReplayTests",
            dependencies: [
                .target(name: "KubesenseSessionReplay"),
                .target(name: "TestUtilities"),
                .product(name: "DatadogSDKTesting", package: "dd-sdk-swift-testing"),
            ],
            path: "KubesenseSessionReplay/Tests",
            resources: [
                .process("Resources/Assets.xcassets")
            ]
        ),
        
        .target(
            name: "KubesenseProfiling",
            dependencies: [
                .target(name: "KubesenseInternal"),
                .target(name: "KubesenseMachProfiler")
            ],
            path: "KubesenseProfiling",
            sources: ["Sources"],
            resources: [
                .copy("Resources/PrivacyInfo.xcprivacy")
            ],
            swiftSettings: [.swiftLanguageMode(.v6)] + internalSwiftSettings
        ),
        .target(
            name: "KubesenseMachProfiler",
            path: "KubesenseProfiling/Mach"
        ),
        .testTarget(
            name: "KubesenseProfilingTests",
            dependencies: [
                .target(name: "KubesenseMachProfiler"),
                .target(name: "KubesenseProfiling"),
                .target(name: "TestUtilities"),
            ],
            path: "KubesenseProfiling/Tests",
            swiftSettings: [.interoperabilityMode(.Cxx), .swiftLanguageMode(.v6)] + internalSwiftSettings
        ),

        .target(
            name: "KubesenseFlags",
            dependencies: [
                .target(name: "KubesenseInternal"),
            ],
            path: "KubesenseFlags/Sources"
        ),
        .testTarget(
            name: "KubesenseFlagsTests",
            dependencies: [
                .target(name: "KubesenseFlags"),
                .target(name: "TestUtilities"),
            ],
            path: "KubesenseFlags/Tests"
        ),

        .target(
            name: "TestUtilities",
            dependencies: [
                .target(name: "KubesenseCore"),
                .target(name: "KubesensePrivate"),
                .target(name: "KubesenseInternal"),
                .target(name: "KubesenseLogs"),
                .target(name: "KubesenseRUM"),
                .target(name: "KubesenseSessionReplay"),
                .target(name: "KubesenseTrace"),
                .target(name: "KubesenseCrashReporting"),
                .target(name: "KubesenseWebViewTracking"),
                .target(name: "KubesenseFlags"),
            ],
            path: "TestUtilities/Sources",
            swiftSettings: [.define("SPM_BUILD")] + internalSwiftSettings
        )
    ],
    swiftLanguageModes: [.v5],
    cxxLanguageStandard: .cxx17
)

// If the `KUBESENSE_TEST_UTILITIES_ENABLED` development ENV is set, export additional utility packages.
// To set this ENV for Xcode projects that fetch this package locally, use `open --env KUBESENSE_TEST_UTILITIES_ENABLED path/to/<project or workspace>`.
if ProcessInfo.processInfo.environment["KUBESENSE_TEST_UTILITIES_ENABLED"] != nil {
    package.products.append(
        .library(
            name: "TestUtilities",
            targets: ["TestUtilities"]
        )
    )
}
