/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

#if !os(watchOS)
import XCTest
import KubesenseMachProfiler

final class KubesenseProfilerCAPITests: XCTestCase {
    private var receivedTraces: [UnsafePointer<stack_trace_t>?] = []
    private var receivedCounts: [Int] = []
    private var callbackUserData: UnsafeMutableRawPointer?

    override func setUp() {
        super.setUp()
        receivedTraces.removeAll()
        receivedCounts.removeAll()
        callbackUserData = nil
    }

    // MARK: - Profiler State Management Tests

    func testProfilerState_initiallyNotRunning() {
        XCTAssertFalse(kubesense_profiler_is_running(), "Profiler should not be running until started")
    }

    func testProfilerStart_changesStateToRunning() {
        XCTAssertEqual(kubesense_profiler_start(), 1)
        XCTAssertTrue(kubesense_profiler_is_running(), "Profiler should be running after start")

        kubesense_profiler_stop()
        kubesense_profiler_destroy()
    }

    func testProfilerStop_changesStateToNotRunning() {
        XCTAssertEqual(kubesense_profiler_start(), 1)
        XCTAssertTrue(kubesense_profiler_is_running(), "Precondition: profiler should be running")

        kubesense_profiler_stop()

        XCTAssertFalse(kubesense_profiler_is_running(), "Profiler should not be running after stop")

        kubesense_profiler_destroy()
    }

    func testProfilerStartTwice_doesNotCrash() {
        XCTAssertEqual(kubesense_profiler_start(), 1)

        let secondStartResult = kubesense_profiler_start()

        XCTAssertEqual(secondStartResult, 1, "Second start while running should succeed (idempotent)")
        XCTAssertTrue(kubesense_profiler_is_running(), "Profiler should still be running")

        kubesense_profiler_stop()
        kubesense_profiler_destroy()
    }

    // MARK: - Memory Management Tests

    func testProfilerDestroy_stopsRunningProfiler() {
        XCTAssertEqual(kubesense_profiler_start(), 1)
        XCTAssertTrue(kubesense_profiler_is_running())

        kubesense_profiler_destroy()

        // Then
        // Should have cleaned up resources without crashing
        // Note: Can't test is_running after destroy as profiler is deallocated
    }
}
#endif // !os(watchOS)
