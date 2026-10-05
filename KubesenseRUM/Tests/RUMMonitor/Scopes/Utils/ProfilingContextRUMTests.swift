/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import XCTest
import KubesenseInternal
@testable import KubesenseRUM

final class ProfilingContextRUMTests: XCTestCase {
    func testKubesenseProfiling_mapsRunningStatus() {
        let profiling = ProfilingContext(status: .running).kubesenseProfiling

        XCTAssertEqual(profiling.status, .running)
        XCTAssertNil(profiling.errorReason)
        XCTAssertNil(profiling.quotaReason)
    }

    func testKubesenseProfiling_mapsStoppedStatus() throws {
        let stopReasons: [ProfilingContext.Status.StopReason] = [.manual, .notStarted, .timeout, .prewarmed]
        let quotaReasons: [KubesenseProfiling.QuotaReason] = [
            .quotaOk, .quotaExceeded, .orgDisabled, .backendUnavailable, .undefined, .timeout, .apiError
        ]

        let quotaReason = try XCTUnwrap(quotaReasons.randomElement())
        let stoppedProfiling = ProfilingContext(
            status: .stopped(reason: try XCTUnwrap(stopReasons.randomElement())),
            quotaReason: quotaReason
        ).kubesenseProfiling

        XCTAssertEqual(stoppedProfiling.status, .stopped)
        XCTAssertNil(stoppedProfiling.errorReason)
        XCTAssertEqual(stoppedProfiling.quotaReason, quotaReason)
    }

    func testKubesenseProfiling_mapsErrorStatus() {
        let memoryAllocationFailure = ProfilingContext(status: .error(reason: .memoryAllocationFailed)).kubesenseProfiling

        XCTAssertEqual(memoryAllocationFailure.status, .error)
        XCTAssertEqual(memoryAllocationFailure.errorReason, .unexpectedException)
        XCTAssertNil(memoryAllocationFailure.quotaReason)

        let alreadyStarted = ProfilingContext(status: .error(reason: .alreadyStarted)).kubesenseProfiling

        XCTAssertEqual(alreadyStarted.status, .error)
        XCTAssertNil(alreadyStarted.errorReason)
        XCTAssertNil(alreadyStarted.quotaReason)

        let unknown = ProfilingContext(status: .unknown).kubesenseProfiling

        XCTAssertEqual(unknown.status, .error)
        XCTAssertNil(unknown.errorReason)
        XCTAssertNil(unknown.quotaReason)
    }
}
