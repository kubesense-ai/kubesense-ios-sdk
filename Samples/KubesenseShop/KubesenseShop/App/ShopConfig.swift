/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Kubesense addition to the fork of dd-sdk-ios, see docs/UPSTREAM_SYNC.md.
 */

import Foundation

/// Which Kubesense features the app starts. The benchmarks compare them; a normal run uses `.full`.
enum SDKProfile: String {
    /// No SDK at all: the baseline.
    case off
    /// Core and RUM only.
    case rum
    /// Core, RUM and Session Replay.
    case replay
    /// Every feature the sample exercises, Session Replay included.
    case full
}

/// Values from `Config/local.json` (or `Config/example.json`), bundled as `config.json` at build time.
/// The process environment overrides any of them, which is how UI tests and benchmarks steer the app.
struct ShopConfig {
    let clientToken: String
    let applicationID: String
    let rumEndpoint: String
    let env: String
    let sampleApiBaseURL: String
    let flavor: String
    let sdkProfile: SDKProfile
    /// SDK console logging; off for benchmarks, where printing would be measured too.
    let sdkVerbose: Bool

    var hasCredentials: Bool { !clientToken.isEmpty && !applicationID.isEmpty }

    static func load(bundle: Bundle = .main, environment: [String: String] = ProcessInfo.processInfo.environment) -> ShopConfig {
        let values = bundle.url(forResource: "config", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: String] } ?? [:]
        func value(_ key: String) -> String {
            (environment[key] ?? values[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ShopConfig(
            clientToken: value("KUBESENSE_CLIENT_TOKEN"),
            applicationID: value("KUBESENSE_APPLICATION_ID"),
            rumEndpoint: value("KUBESENSE_RUM_ENDPOINT"),
            env: value("KUBESENSE_ENV").isEmpty ? "dev" : value("KUBESENSE_ENV"),
            sampleApiBaseURL: value("SAMPLE_API_BASE_URL"),
            flavor: value("FLAVOR").isEmpty ? "local" : value("FLAVOR"),
            sdkProfile: SDKProfile(rawValue: value("KUBESENSE_SDK_PROFILE")) ?? .full,
            sdkVerbose: value("KUBESENSE_SDK_VERBOSE") != "0"
        )
    }
}
