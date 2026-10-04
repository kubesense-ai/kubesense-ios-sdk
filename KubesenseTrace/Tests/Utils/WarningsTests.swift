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

        let dd = DD.mockWith(logger: CoreLoggerMock())
        defer { dd.reset() }

        XCTAssertTrue(warn(if: true, message: "message"))
        XCTAssertEqual(dd.logger.warnLog?.message, "message")

        dd.logger.reset()

        XCTAssertFalse(warn(if: false, message: "message"))
        XCTAssertNil(dd.logger.warnLog)

        dd.logger.reset()

        let failingCast: () -> KubesenseSpan? = { warnIfCannotCast(value: KubesenseNoopSpan()) }
        XCTAssertNil(failingCast())
        XCTAssertEqual(dd.logger.warnLog?.message, "🔥 Using KubesenseNoopSpan while KubesenseSpan was expected.")

        dd.logger.reset()

        let succeedingCast: () -> KubesenseSpan? = { warnIfCannotCast(value: KubesenseSpan.mockAny(in: core)) }
        XCTAssertNotNil(succeedingCast())
        XCTAssertNil(dd.logger.warnLog)
    }
}
