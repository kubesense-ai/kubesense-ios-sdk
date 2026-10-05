/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import XCTest
import TestUtilities
import KubesenseInternal
@testable import KubesenseRUM

final class AppLaunchMetricControllerTests: XCTestCase {
    private let telemetry = TelemetryMock()

    func testTrackingAppLaunchMetric() throws {
        // Given
        let kubesenseContext: KubesenseContext = .mockRandom()
        let vitalEvent: RUMVitalAppLaunchEvent = .mockWith(
            vital: .mockWith(
                appLaunchMetric: .ttid,
                isPrewarmed: kubesenseContext.launchInfo.launchReason == .prewarming
            )
        )
        let coldStartRule: ColdStartRule = .appUpdate
        let controller = AppLaunchMetricController(telemetry: telemetry)

        // When
        controller.track(coldStartRule: coldStartRule)
        controller.track(ttidEvent: vitalEvent, context: kubesenseContext)
        controller.sendMetric()

        // Then
        let metric = try XCTUnwrap(telemetry.messages.appLaunchMetric)
        XCTAssertEqual(metric.ttidDurationNs, vitalEvent.vital.duration.kubesense.toInt64Nanoseconds)
        XCTAssertEqual(metric.startupType, vitalEvent.vital.startupType?.rawValue)
        XCTAssertEqual(metric.coldStartRule, coldStartRule.rawValue)
        XCTAssertEqual(metric.isPrewarmed, vitalEvent.vital.isPrewarmed)
        XCTAssertEqual(metric.launchReason, kubesenseContext.launchInfo.launchReason)
        XCTAssertEqual(metric.taskPolicyRole, kubesenseContext.launchInfo.raw.taskPolicyRole)
        XCTAssertEqual(metric.pois.count, 5)

        let metricTelemetry = try XCTUnwrap(telemetry.messages.lastMetric(named: AppLaunchMetric.Constants.name))
        XCTAssertEqual(metricTelemetry.sampleRate, 20.0)
    }

    func testTrackingLargeTTID() throws {
        // Given
        let kubesenseContext: KubesenseContext = .mockRandom()
        let controller = AppLaunchMetricController(telemetry: telemetry)
        let duration: TimeInterval = 1_000

        // When
        controller.send(metric: .largeTTID(context: kubesenseContext, duration: duration))

        // Then
        let metric = try XCTUnwrap(telemetry.messages.appLaunchMetric)
        XCTAssertEqual(metric.ttidDurationNs, duration.kubesense.toInt64Nanoseconds)
        XCTAssertEqual(metric.launchReason, kubesenseContext.launchInfo.launchReason)
        XCTAssertEqual(metric.taskPolicyRole, kubesenseContext.launchInfo.raw.taskPolicyRole)
        XCTAssertEqual(metric.isPrewarmed, kubesenseContext.launchInfo.launchReason == .prewarming)
        XCTAssertEqual(metric.pois.count, 5)
        XCTAssertFalse(metric.errorMessage?.isEmpty ?? true)

        let metricTelemetry = try XCTUnwrap(telemetry.messages.lastMetric(named: AppLaunchMetric.Constants.name))
        XCTAssertEqual(metricTelemetry.sampleRate, 20.0)
    }

    func testTrackingLaunchNotSupported() throws {
        // Given
        let kubesenseContext: KubesenseContext = .mockRandom()
        let controller = AppLaunchMetricController(telemetry: telemetry)
        let duration: TimeInterval = 1_000

        // When
        controller.send(metric: .launchNotSupported(context: kubesenseContext, duration: duration))

        // Then
        let metric = try XCTUnwrap(telemetry.messages.appLaunchMetric)
        XCTAssertEqual(metric.ttidDurationNs, duration.kubesense.toInt64Nanoseconds)
        XCTAssertEqual(metric.launchReason, kubesenseContext.launchInfo.launchReason)
        XCTAssertEqual(metric.taskPolicyRole, kubesenseContext.launchInfo.raw.taskPolicyRole)
        XCTAssertEqual(metric.isPrewarmed, kubesenseContext.launchInfo.launchReason == .prewarming)
        XCTAssertEqual(metric.pois.count, 5)
        XCTAssertFalse(metric.errorMessage?.isEmpty ?? true)

        let metricTelemetry = try XCTUnwrap(telemetry.messages.lastMetric(named: AppLaunchMetric.Constants.name))
        XCTAssertEqual(metricTelemetry.sampleRate, 20.0)
    }

    func testTrackingAppLaunchMetric_withTTFDRecordedFirst() throws {
        // Given
        let kubesenseContext: KubesenseContext = .mockRandom()
        let vitalEvent: RUMVitalAppLaunchEvent = .mockAny()
        let controller = AppLaunchMetricController(telemetry: telemetry)
        let ttfdDuration: Int64 = 1_000

        // When
        controller.track(ttidEvent: vitalEvent, context: kubesenseContext)
        controller.trackTTFD(duration: ttfdDuration)
        controller.sendMetric()

        // Then
        let metric = try XCTUnwrap(telemetry.messages.appLaunchMetric)
        XCTAssertEqual(metric.ttidDurationNs, vitalEvent.vital.duration.kubesense.toInt64Nanoseconds)
        XCTAssertEqual(metric.startupType, vitalEvent.vital.startupType?.rawValue)
        XCTAssertEqual(metric.launchReason, kubesenseContext.launchInfo.launchReason)
        XCTAssertEqual(metric.taskPolicyRole, kubesenseContext.launchInfo.raw.taskPolicyRole)
        XCTAssertEqual(metric.pois.count, 5)
        XCTAssertEqual(metric.ttfdDurationNs, ttfdDuration)

        let metricTelemetry = try XCTUnwrap(telemetry.messages.lastMetric(named: AppLaunchMetric.Constants.name))
        XCTAssertEqual(metricTelemetry.sampleRate, 20.0)
    }

    func testTrackingMoreThanOneTTID() throws {
        // Given
        let kubesenseContext: KubesenseContext = .mockRandom()
        let vitalEvent: RUMVitalAppLaunchEvent = .mockAny()
        let controller = AppLaunchMetricController(telemetry: telemetry)

        // When
        controller.track(ttidEvent: vitalEvent, context: kubesenseContext)
        controller.incrementTTIDCounter()
        controller.incrementTTIDCounter()
        controller.sendMetric()

        // Then
        let metric = try XCTUnwrap(telemetry.messages.appLaunchMetric)
        XCTAssertEqual(metric.ttidDurationNs, vitalEvent.vital.duration.kubesense.toInt64Nanoseconds)
        XCTAssertEqual(metric.startupType, vitalEvent.vital.startupType?.rawValue)
        XCTAssertEqual(metric.launchReason, kubesenseContext.launchInfo.launchReason)
        XCTAssertEqual(metric.taskPolicyRole, kubesenseContext.launchInfo.raw.taskPolicyRole)
        XCTAssertEqual(metric.pois.count, 5)
        XCTAssertEqual(metric.extraTTIDsCount, 2)

        let metricTelemetry = try XCTUnwrap(telemetry.messages.lastMetric(named: AppLaunchMetric.Constants.name))
        XCTAssertEqual(metricTelemetry.sampleRate, 20.0)
    }

    func testTrackingMultipleAppLaunchMetrics() throws {
        // Given
        let iterations = 10
        let kubesenseContext: KubesenseContext = .mockRandom()
        let vitalEvent: RUMVitalAppLaunchEvent = .mockAny()
        let controller = AppLaunchMetricController(telemetry: telemetry)
        let appLaunchMetric = try XCTUnwrap(AppLaunchMetric(vitalEvent: vitalEvent, context: kubesenseContext))

        // When
        (0..<iterations).forEach { _ in
            controller.send(metric: appLaunchMetric)
        }

        // Then
        XCTAssertEqual(telemetry.messages.count, iterations)
        try (0..<iterations).forEach {
            let metric = try XCTUnwrap(telemetry.messages[$0]
                .asMetric?.attributes[AppLaunchMetric.Constants.appLaunchKey] as? AppLaunchMetric.Attributes)

            XCTAssertEqual(metric.ttidDurationNs, vitalEvent.vital.duration.kubesense.toInt64Nanoseconds)
            XCTAssertEqual(metric.startupType, vitalEvent.vital.startupType?.rawValue)
            XCTAssertEqual(metric.launchReason, kubesenseContext.launchInfo.launchReason)
            XCTAssertEqual(metric.taskPolicyRole, kubesenseContext.launchInfo.raw.taskPolicyRole)
            XCTAssertEqual(metric.pois.count, 5)
        }
    }
}

// MARK: - Helpers

private extension Array where Element == TelemetryMessage {
    var appLaunchMetric: AppLaunchMetric.Attributes? {
        lastMetric(named: AppLaunchMetric.Constants.name)?
            .attributes[AppLaunchMetric.Constants.appLaunchKey] as? AppLaunchMetric.Attributes
    }
}
