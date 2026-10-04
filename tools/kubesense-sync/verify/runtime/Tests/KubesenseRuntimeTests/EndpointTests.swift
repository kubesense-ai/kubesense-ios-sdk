/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Kubesense addition to the fork of dd-sdk-ios, see docs/UPSTREAM_SYNC.md.
 */

import Foundation
import Testing
import KubesenseInternal
@testable import KubesenseCore

@Suite struct EndpointTests {
    @Test func sites() {
        #expect(KubesenseSite.prod.endpoint.absoluteString == "https://us2.kubesense.ai/")
        #expect(KubesenseSite.staging.endpoint.absoluteString == "https://dev.kubesense.ai/")
        #expect(KubesenseSite.prod.endpoint.appendingPathComponent("rum/api/v1").absoluteString == "https://us2.kubesense.ai/rum/api/v1")
    }

    @Test(arguments: [
        ("intake.example.com", "https://intake.example.com"),
        ("  https://intake.example.com/  ", "https://intake.example.com"),
        ("HTTP://intake.example.com:8080/rum/api/v1", "https://intake.example.com:8080"),
    ])
    func kubesenseRumEndpointIsNormalized(value: String, expected: String) {
        var configuration = Kubesense.Configuration(clientToken: "abc", env: "tests")
        configuration.kubesenseRumEndpoint = value
        #expect(configuration.kubesenseRumEndpointURL?.absoluteString == expected)
    }

    @Test(arguments: [nil, "", "https://", "   "] as [String?])
    func invalidKubesenseRumEndpointsAreIgnored(value: String?) {
        var configuration = Kubesense.Configuration(clientToken: "abc", env: "tests")
        configuration.kubesenseRumEndpoint = value
        #expect(configuration.kubesenseRumEndpointURL == nil)
    }

    @Test func defaults() {
        let configuration = Kubesense.Configuration(clientToken: "abc", env: "tests")
        #expect(configuration.site == .prod)
        #expect(configuration.remoteConfigurationEnabled)
        #expect(configuration.remoteConfigurationRefreshPeriod == 21_600)
    }

    @Test func contextIntakeEndpointDefaultsToTheSite() {
        #expect(KubesenseSite.staging.endpoint == URL(string: "https://dev.kubesense.ai/"))
    }
}
