/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

#if !os(watchOS)

import XCTest
import KubesenseProfiling

final class ProfilingConfigurationTests: XCTestCase {
    func testDefaultConfiguration() {
        // When
        let endpoint: URL = .mockRandom()
        var config = Profiling.Configuration()
        config.customEndpoint = endpoint

        // Then
        XCTAssertEqual(config.customEndpoint, endpoint)
        XCTAssertEqual(config.applicationLaunchSampleRate, 5)
        XCTAssertEqual(config.continuousSampleRate, 5)
    }
}

#endif
