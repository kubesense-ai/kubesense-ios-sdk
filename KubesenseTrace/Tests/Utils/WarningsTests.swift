/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import XCTest
import TestUtilities
import KubesenseInternal

@testable import KubesenseTrace

class WarningsTests: XCTestCase {
    func testPrintingWarningsOnDifferentConditions() {
        let core = PassthroughCoreMock()

        let kubesense = KS.mockWith(logger: CoreLoggerMock())
        defer { kubesense.reset() }

        XCTAssertTrue(warn(if: true, message: "message"))
        XCTAssertEqual(kubesense.logger.warnLog?.message, "message")

        kubesense.logger.reset()

        XCTAssertFalse(warn(if: false, message: "message"))
        XCTAssertNil(kubesense.logger.warnLog)

        kubesense.logger.reset()

        let failingCast: () -> KubesenseSpan? = { warnIfCannotCast(value: KubesenseNoopSpan()) }
        XCTAssertNil(failingCast())
        XCTAssertEqual(kubesense.logger.warnLog?.message, "🔥 Using KubesenseNoopSpan while KubesenseSpan was expected.")

        kubesense.logger.reset()

        let succeedingCast: () -> KubesenseSpan? = { warnIfCannotCast(value: KubesenseSpan.mockAny(in: core)) }
        XCTAssertNotNil(succeedingCast())
        XCTAssertNil(kubesense.logger.warnLog)
    }
}
