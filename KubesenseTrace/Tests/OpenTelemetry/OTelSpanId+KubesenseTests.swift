/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import XCTest
import TestUtilities
import KubesenseInternal
import OpenTelemetryApi

@testable import KubesenseTrace

class OTelSpanIdKubesenseTests: XCTestCase {
    func testToKubesense() {
        let otelId = SpanId.random()
        let kubesenseId = otelId.toKubesense()
        XCTAssertEqual(otelId.rawValue, kubesenseId.rawValue)
    }
}
