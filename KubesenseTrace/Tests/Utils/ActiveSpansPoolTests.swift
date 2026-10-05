/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import XCTest
import TestUtilities
import KubesenseInternal

@testable import KubesenseTrace
@testable import KubesenseCore

@MainActor
class ActiveSpansPoolTests: XCTestCase, Sendable {
    private var core: KubesenseCoreProtocol! // swiftlint:disable:this implicitly_unwrapped_optional

    override func setUp() async throws {
        core = PassthroughCoreMock()
    }

    override func tearDown() async throws {
        core = nil
    }

    func testsWhenSpanIsStartedIsAssignedToActiveSpan() throws {
        let tracer = KubesenseTracer.mockAny(in: core)
        let previousSpan = tracer.activeSpan
        XCTAssertNil(previousSpan)

        let oneSpan = tracer.startSpan(operationName: .mockAny()).setActive()
        XCTAssert(tracer.activeSpan?.kubesense.kubesenseContext.spanID == oneSpan.kubesense.kubesenseContext.spanID)
        oneSpan.finish()
        XCTAssertNil(tracer.activeSpan)
        XCTAssertTrue(tracer.activeSpansPool.isEmpty)
    }

    func testsWhenSpanIsFinishedIsRemovedFromActiveSpan() throws {
        let tracer = KubesenseTracer.mockAny(in: core)
        XCTAssertNil(tracer.activeSpan)

        let oneSpan = tracer.startSpan(operationName: .mockAny()).setActive()
        XCTAssert(tracer.activeSpan?.kubesense.kubesenseContext.spanID == oneSpan.kubesense.kubesenseContext.spanID)

        oneSpan.finish()
        XCTAssertNil(tracer.activeSpan)
        XCTAssertTrue(tracer.activeSpansPool.isEmpty)
    }

    func testsSpanWithoutParentInheritsActiveSpan() throws {
        let tracer = KubesenseTracer.mockAny(in: core)
        let firstSpan = tracer.startSpan(operationName: .mockAny())
        firstSpan.setActive()
        let previousActiveSpan = tracer.activeSpan
        let secondSpan = tracer.startSpan(operationName: .mockAny())
        secondSpan.setActive()
        XCTAssertEqual(secondSpan.kubesense.kubesenseContext.parentSpanID, previousActiveSpan?.kubesense.kubesenseContext.spanID)
        XCTAssertEqual(secondSpan.kubesense.kubesenseContext.spanID,  tracer.activeSpan?.kubesense.kubesenseContext.spanID)
        XCTAssertEqual(secondSpan.kubesense.kubesenseContext.parentSpanID, firstSpan.kubesense.kubesenseContext.spanID)

        secondSpan.finish()
        XCTAssertEqual(tracer.activeSpan?.kubesense.kubesenseContext.spanID, firstSpan.kubesense.kubesenseContext.spanID)
        firstSpan.finish()
        XCTAssertNil(tracer.activeSpan)
        XCTAssertTrue(tracer.activeSpansPool.isEmpty)
    }

    func testsSpanWithParentDoesntInheritActiveSpan() throws {
        let tracer = KubesenseTracer.mockAny(in: core)
        let oneSpan = tracer.startSpan(operationName: .mockAny())
        let otherSpan = tracer.startSpan(operationName: .mockAny()).setActive()

        let spanWithParent = tracer.startSpan(operationName: .mockAny(), childOf: oneSpan.context)

        XCTAssertEqual(spanWithParent.kubesense.kubesenseContext.parentSpanID, oneSpan.kubesense.kubesenseContext.spanID)
        spanWithParent.finish()
        XCTAssertEqual(tracer.activeSpan?.kubesense.kubesenseContext.spanID, otherSpan.kubesense.kubesenseContext.spanID)
        oneSpan.finish()
        otherSpan.finish()
        XCTAssertNil(tracer.activeSpan)
        XCTAssertTrue(tracer.activeSpansPool.isEmpty)
    }

    func testActiveSpanIsKeptPerTask() async throws {
        let tracer = KubesenseTracer.mockAny(in: core)
        let oneSpan = tracer.startSpan(operationName: .mockAny()).setActive()

        let task1 = Task {
            let firstSpan = tracer.startSpan(operationName: .mockAny()).setActive()
            XCTAssertEqual(tracer.activeSpan?.kubesense.kubesenseContext.spanID, firstSpan.kubesense.kubesenseContext.spanID)
            return firstSpan
        }

        let task2 = Task {
            try await Task.sleep(nanoseconds: 500_000_000)
            XCTAssertEqual(tracer.activeSpan?.kubesense.kubesenseContext.spanID, oneSpan.kubesense.kubesenseContext.spanID)
            let secondSpan = tracer.startSpan(operationName: .mockAny()).setActive()
            XCTAssertEqual(tracer.activeSpan?.kubesense.kubesenseContext.spanID, secondSpan.kubesense.kubesenseContext.spanID)
            return secondSpan
        }

        let (firstSpan, secondSpan) = try await (task1.value, task2.value)
        XCTAssertEqual(tracer.activeSpan?.kubesense.kubesenseContext.spanID, oneSpan.kubesense.kubesenseContext.spanID)
        oneSpan.finish()
        firstSpan.finish()
        secondSpan.finish()

        XCTAssertNil(tracer.activeSpan)
        XCTAssertTrue(tracer.activeSpansPool.isEmpty)
    }

    func testSetActiveSpanCalledMultipleTimesInSingleSpan() throws {
        let tracer = KubesenseTracer.mockAny(in: core)
        defer { tracer.activeSpansPool.destroy() }

        let span = tracer.startSpan(operationName: "Reactivated")
        (3...Int.mockRandom(min: 3, max: 10)).forEach { _ in
            span.setActive()
        }

        XCTAssertEqual(tracer.activeSpan?.kubesense.kubesenseContext.spanID, span.kubesense.kubesenseContext.spanID)

        span.finish()

        XCTAssertNil(tracer.activeSpan)
        XCTAssertTrue(tracer.activeSpansPool.isEmpty)
    }

    func testSetActiveSpanCalledMultipleTimesInTwoSpans() throws {
        let tracer = KubesenseTracer.mockAny(in: core)
        defer { tracer.activeSpansPool.destroy() }

        let firstSpan = tracer.startSpan(operationName: .mockAny()).setActive()
        firstSpan.setActive()

        let previousActiveSpan = tracer.activeSpan

        let secondSpan = tracer.startSpan(operationName: .mockAny()).setActive()
        firstSpan.setActive()
        secondSpan.setActive()

        XCTAssertEqual(secondSpan.kubesense.kubesenseContext.parentSpanID, previousActiveSpan?.kubesense.kubesenseContext.spanID)
        XCTAssertEqual(secondSpan.kubesense.kubesenseContext.spanID,  tracer.activeSpan?.kubesense.kubesenseContext.spanID)
        XCTAssertEqual(secondSpan.kubesense.kubesenseContext.parentSpanID, firstSpan.kubesense.kubesenseContext.spanID)

        secondSpan.finish()
        XCTAssertEqual(tracer.activeSpan?.kubesense.kubesenseContext.spanID, firstSpan.kubesense.kubesenseContext.spanID)
        firstSpan.finish()
        XCTAssertNil(tracer.activeSpan)
        XCTAssertTrue(tracer.activeSpansPool.isEmpty)
    }

    func testSetActive_givenParentWithMultipleChildren() throws {
        let tracer = KubesenseTracer.mockAny(in: core)
        defer { tracer.activeSpansPool.destroy() }

        let parentSpan = tracer.startSpan(operationName: .mockAny()).setActive()
        let child1Span = tracer.startSpan(operationName: "Child1").setActive()
        child1Span.finish()

        let child2Span = tracer.startSpan(operationName: "Child2")
        child2Span.finish()
        parentSpan.finish()

        XCTAssertEqual(child1Span.kubesense.kubesenseContext.traceID, parentSpan.kubesense.kubesenseContext.traceID)
        XCTAssertEqual(child1Span.kubesense.kubesenseContext.parentSpanID, parentSpan.kubesense.kubesenseContext.spanID)
        XCTAssertEqual(child2Span.kubesense.kubesenseContext.traceID, parentSpan.kubesense.kubesenseContext.traceID)
        XCTAssertEqual(child2Span.kubesense.kubesenseContext.parentSpanID, parentSpan.kubesense.kubesenseContext.spanID)

        XCTAssertNil(tracer.activeSpan)
        XCTAssertTrue(tracer.activeSpansPool.isEmpty)
    }

    func testSetActive_activeSpanProviderWorks() throws {
        let core = KubesenseCoreProxy()
        Trace.enable(in: core)
        let tracer = Tracer.shared(in: core)

        core.scope(for: TraceFeature.self).context { context in
            guard let provider = context.additionalContext(ofType: TraceCoreContext.ActiveSpanProvider.self) else {
                XCTFail("Additional context for ActiveSpanProvider is nil unexpectedly.")
                return
            }

            XCTAssertNil(provider.activeSpanContext())

            let oneSpan = tracer.startSpan(operationName: .mockAny()).setActive()
            XCTAssertEqual(provider.activeSpanContext()?.activeSpanID, oneSpan.kubesense.kubesenseContext.spanID)
            XCTAssertEqual(provider.activeSpanContext()?.traceID, oneSpan.kubesense.kubesenseContext.traceID)

            oneSpan.finish()
            XCTAssertNil(provider.activeSpanContext())
        }
    }
}
