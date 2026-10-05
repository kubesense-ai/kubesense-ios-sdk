/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import XCTest
import TestUtilities
import KubesenseInternal

@testable import KubesenseTrace

class KubesenseNoopTracerTests: XCTestCase {
    func testWhenUsingKubesenseNoopTracerAPIs_itPrintsWarning() {
        let kubesense = KS.mockWith(logger: CoreLoggerMock())
        defer { kubesense.reset() }

        // Given
        let noop = KubesenseNoopTracer()

        // When
        let context = KubesenseSpanContext.mockAny()
        noop.inject(
            spanContext: context,
            writer: HTTPHeadersWriter(traceContextInjection: .sampled)
        )
        _ = noop.extract(reader: HTTPHeadersReader(httpHeaderFields: [:]))
        let root = noop.startRootSpan(operationName: "root operation").setActive()
        let child = noop.startSpan(operationName: "child operation")
        child.finish()
        root.finish()

        // Then
        let expectedWarningMessage = """
        The `KubesenseTracer.shared()` was called but `KubesenseTracer` is not initialised. Configure the `KubesenseTracer` before invoking the feature:
            KubesenseTracer.initialize()
        See https://docs.kubesense.ai/tracing/setup_overview/setup/ios
        """

        XCTAssertEqual(kubesense.logger.warnLogs.count, 4)
        kubesense.logger.warnLogs.forEach { log in
            XCTAssertEqual(log.message, expectedWarningMessage)
        }
    }
}
