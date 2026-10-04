/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

#if !os(watchOS)

import XCTest
@testable import KubesenseInternal
import TestUtilities

@testable import KubesenseProfiling
import KubesenseMachProfiler

class ProfilingTest: XCTestCase {
    private let primaryInstanceName = "primary"
    private let secondaryInstanceName = "secondary"

    override func setUp() {
        super.setUp()
        CoreRegistry.unregisterDefault()
        CoreRegistry.unregisterInstance(named: primaryInstanceName)
        CoreRegistry.unregisterInstance(named: secondaryInstanceName)
        kubesense_profiler_stop()
        kubesense_profiler_destroy()
    }

    override func tearDown() {
        CoreRegistry.unregisterDefault()
        CoreRegistry.unregisterInstance(named: primaryInstanceName)
        CoreRegistry.unregisterInstance(named: secondaryInstanceName)
        kubesense_profiler_stop()
        kubesense_profiler_destroy()
        super.tearDown()
    }

    func testProfilingConfiguration() throws {
        // Given
        var configuration = Profiling.Configuration()
        configuration.customEndpoint = .mockRandom()
        let core = SingleFeatureCoreMock<ProfilerFeature>()
        XCTAssertEqual(kubesense_profiler_start(), 1)
        defer { kubesense_profiler_destroy() }

        // When
        Profiling.enable(with: configuration, in: core)

        // Then
        let feature = core.feature(named: ProfilerFeature.name, type: ProfilerFeature.self)
        let requestBuilder = feature?.requestBuilder as? RequestBuilder
        XCTAssertEqual(feature?.performanceOverride?.maxFileSize, 15.MB.asUInt32())
        XCTAssertEqual(requestBuilder?.customUploadURL, configuration.customEndpoint)
        XCTAssertEqual(feature?.telemetryController.sampleRate, 20)

        let context = try XCTUnwrap(core.context.additionalContext(ofType: ProfilingContext.self))
        XCTAssertEqual(context.status, .running)
    }

    func testProfilingFeature_usesTheAdmittingQuotaChecker() throws {
        // Given
        let core = SingleFeatureCoreMock<ProfilerFeature>()
        XCTAssertEqual(kubesense_profiler_start(), 1)
        defer { kubesense_profiler_destroy() }

        // When
        Profiling.enable(in: core)

        // Then — no quota request is ever sent: the Kubesense collector has no quota route
        let feature = try XCTUnwrap(core.feature(named: ProfilerFeature.name, type: ProfilerFeature.self))
        let receivers = try XCTUnwrap(feature.messageReceiver as? CombinedFeatureMessageReceiver).receivers
        XCTAssertNotNil(receivers.firstElement(of: AdmittingProfilingQuotaChecker.self))
        XCTAssertNil(receivers.firstElement(of: ProfilingQuotaChecker.self))
    }

    // MARK: - Kubesense Remote Configuration Document

    func testWhenSwitchedOffRemotely_itIsNotEnabled() {
        // Given
        let core = SingleFeatureCoreMock<ProfilerFeature>()
        core.remoteConfigDocument = .parse(Data(#"{"features":{"profiling":false}}"#.utf8))

        // When
        Profiling.enable(in: core)

        // Then
        XCTAssertNil(core.feature(named: ProfilerFeature.name, type: ProfilerFeature.self))
    }

    // MARK: - Remote Configuration

    func testWhenEnabledWithRemoteConfiguration_itInjectsApplicationLaunchSampleRate() throws {
        // Clear the shared suite so the feature's "lowest sample rate wins" persistence is deterministic.
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: KUBESENSE_PROFILING_USER_DEFAULTS_SUITE_NAME))
        kubesense_delete_profiling_defaults()
        defer { kubesense_delete_profiling_defaults() }

        // Given a remote `profiling` namespace overriding the in-code application launch sample rate
        let configuration = Profiling.Configuration(applicationLaunchSampleRate: 5)
        let core = SingleFeatureCoreMock<ProfilerFeature>()
        core.remoteConfiguration = .mockWith(profiling: .mockWith(applicationLaunchSampleRate: 100))
        kubesense_profiler_start_testing(100, false, 5.seconds.dd.toInt64Nanoseconds, 0)
        defer { kubesense_profiler_destroy() }

        // When
        Profiling.enable(with: configuration, in: core)

        // Then the merged remote sample rate is injected into the feature and persisted at enable time
        XCTAssertNotNil(core.feature(named: ProfilerFeature.name, type: ProfilerFeature.self))
        XCTAssertEqual(userDefaults.value(forKey: KUBESENSE_PROFILING_APP_LAUNCH_SAMPLE_RATE_KEY) as? SampleRate, 100)
    }

    func testWhenEnabledInMultipleCoreInstances_itPrintsErrorAndKeepsFirstFeature() {
        // Given
        let firstCore = FeatureRegistrationCoreMock()
        let secondCore = FeatureRegistrationCoreMock()
        CoreRegistry.register(firstCore, named: primaryInstanceName)
        CoreRegistry.register(secondCore, named: secondaryInstanceName)

        let printFunction = PrintFunctionSpy()
        consolePrint = printFunction.print
        defer { consolePrint = { message, _ in print(message) } }

        // When
        Profiling.enable(in: firstCore)
        Profiling.enable(in: secondCore)

        // Then
        XCTAssertNotNil(firstCore.get(feature: ProfilerFeature.self))
        XCTAssertNil(secondCore.get(feature: ProfilerFeature.self))
        XCTAssertEqual(
            printFunction.printedMessage,
            "🔥 Kubesense SDK usage error: Profiling is already enabled in SDK instance 'primary' and does not support multiple instances. The existing instance will continue to be used."
        )
    }
}

#endif
