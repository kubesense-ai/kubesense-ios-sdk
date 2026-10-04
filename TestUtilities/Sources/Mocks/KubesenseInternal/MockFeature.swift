/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import Foundation
import KubesenseInternal

internal class MockFeature: KubesenseRemoteFeature {
    static var name = "mock-feature"

    var messageReceiver: FeatureMessageReceiver = NOPFeatureMessageReceiver()
    var requestBuilder: FeatureRequestBuilder = MockRequestBuilder()
    var performanceOverride: PerformancePresetOverride?
}

internal class MockRequestBuilder: FeatureRequestBuilder {
    func request(for events: [KubesenseInternal.Event], with context: KubesenseInternal.KubesenseContext, execution: KubesenseInternal.ExecutionContext) throws -> URLRequest {
        URLRequest.mockAny()
    }
}
