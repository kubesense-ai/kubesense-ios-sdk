/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Kubesense addition to the fork of dd-sdk-ios, see docs/UPSTREAM_SYNC.md.
 */

import Foundation
import Testing
import KubesenseInternal
@testable import KubesenseCore
@testable import KubesenseLogs
@testable import KubesenseTrace
@testable import KubesenseFlags

/// The upload URL, query and headers of the features that build on macOS, on the context of a real core:
/// every feature must upload to the one collector of `kubesenseRumEndpoint`, on the Android SDK's paths.
@Suite(.serialized) struct UploadURLTests {
    @MainActor
    func context(kubesenseRumEndpoint: String?) throws -> KubesenseContext {
        let caches = try temporaryDirectory()
        var configuration = Kubesense.Configuration(
            clientToken: "client-token",
            env: "tests",
            kubesenseRumEndpoint: kubesenseRumEndpoint,
            remoteConfigurationEnabled: false
        )
        configuration.systemDirectory = { caches }
        configuration.httpClientFactory = { _ in RecordingHTTPClient(statusCode: 202, body: nil) }
        let core = try KubesenseCore(configuration: configuration, trackingConsent: .granted, instanceName: "urls-\(UUID().uuidString)")
        defer { core.stop() }
        return core.contextProvider.read()
    }

    let event = Event(data: Data(#"{"a":1}"#.utf8))
    let execution = ExecutionContext(previousResponseCode: nil, attempt: 0)

    @MainActor @Test func logsUploadToTheCollector() throws {
        let request = KubesenseLogs.RequestBuilder().request(
            for: [event], with: try context(kubesenseRumEndpoint: "https://collector.example.com/ignored"), execution: execution
        )
        #expect(request.url?.absoluteString == "https://collector.example.com/rum/api/v1/logs?ksource=ios")
        #expect(request.value(forHTTPHeaderField: "KUBESENSE-API-KEY") == "client-token")
        #expect(request.value(forHTTPHeaderField: "KUBESENSE-EVP-ORIGIN") == "ios")
        #expect(request.value(forHTTPHeaderField: "KUBESENSE-EVP-ORIGIN-VERSION") == "1.0.0")
        #expect(request.value(forHTTPHeaderField: "KUBESENSE-REQUEST-ID") != nil)
    }

    @MainActor @Test func spansUploadToTheCollector() throws {
        let request = TracingRequestBuilder(customIntakeURL: nil, telemetry: NOPTelemetry()).request(
            for: [event], with: try context(kubesenseRumEndpoint: nil), execution: execution
        )
        #expect(request.url?.absoluteString == "https://us2.kubesense.ai/rum/api/v1/spans")
        #expect(request.value(forHTTPHeaderField: "KUBESENSE-API-KEY") == "client-token")
    }

    @MainActor @Test func flagExposuresUploadToTheCollector() throws {
        let request = try ExposureRequestBuilder(customIntakeURL: nil, telemetry: NOPTelemetry()).request(
            for: [event], with: try context(kubesenseRumEndpoint: "collector.example.com:8443"), execution: execution
        )
        #expect(request.url?.absoluteString == "https://collector.example.com:8443/rum/api/v1/exposures?ksource=ios")
        #expect(request.value(forHTTPHeaderField: "KUBESENSE-API-KEY") == "client-token")
    }

    @MainActor @Test func queryParametersUseTheKubesenseNames() throws {
        let retry = ExecutionContext(previousResponseCode: 500, attempt: 2)
        let request = KubesenseLogs.RequestBuilder().request(
            for: [event], with: try context(kubesenseRumEndpoint: nil), execution: retry
        )
        let query = try #require(request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?.queryItems)
        #expect(query.contains(URLQueryItem(name: "ksource", value: "ios")))
        #expect(!query.contains { $0.name.hasPrefix("dd") })
    }
}
