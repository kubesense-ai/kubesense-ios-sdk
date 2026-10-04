/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import XCTest
import KubesenseInternal
import TestUtilities

@testable import KubesenseLogs

class LogsTests: XCTestCase {
    func testDefaultConfiguration() {
        // Given
        let config = Logs.Configuration()

        // Then
        XCTAssertNil(config.eventMapper)
        XCTAssertNil(config.customEndpoint)
    }

    func testWhenNotEnabled_thenLogsIsEnabledIsFalse() {
        // When
        let core = FeatureRegistrationCoreMock()
        XCTAssertNil(core.get(feature: LogsFeature.self))

        // Then
        XCTAssertFalse(Logs._internal.isEnabled(in: core))
    }

    func testWhenEnabled_thenLogsIsEnabledIsTrue() {
        // When
        let core = FeatureRegistrationCoreMock()
        let config = Logs.Configuration()
        Logs.enable(with: config, in: core)

        // Then
        XCTAssertTrue(Logs._internal.isEnabled(in: core))
    }

    func testInitializedWithBacktraceReporter() throws {
        // Given
        let core = FeatureRegistrationCoreMock()

        // When
        Logs.enable(in: core)

        // Then
        let logs = try XCTUnwrap(core.get(feature: LogsFeature.self))
        XCTAssertNotNil(logs.backtraceReporter)
    }

    func testConfigurationOverrides() throws {
        // Given
        let customEndpoint: URL = .mockRandom()

        let core = SingleFeatureCoreMock<LogsFeature>()

        // When
        var configuration = Logs.Configuration(eventMapper: { $0 })
        configuration.customEndpoint = customEndpoint
        Logs.enable(with: configuration, in: core)

        // Then
        let logs = try XCTUnwrap(core.get(feature: LogsFeature.self))
        let requestBuilder = try XCTUnwrap(logs.requestBuilder as? RequestBuilder)
        XCTAssertNotNil(logs.logEventMapper)
        XCTAssertEqual(requestBuilder.customIntakeURL, customEndpoint)
    }

    func testConfigurationInternalOverrides() throws {
        struct LogEventMapperMock: LogEventMapper {
            func map(event: KubesenseLogs.LogEvent, callback: @escaping (KubesenseLogs.LogEvent) -> Void) {
                callback(event)
            }
        }

        // Given
        let eventMapper = LogEventMapperMock()
        var config = Logs.Configuration()

        // When
        config._internal_mutation {
            $0.setLogEventMapper(eventMapper)
        }

        // Then
        XCTAssertTrue(config._internalEventMapper is LogEventMapperMock)
    }

    func testLogsAddAttributeForwardedToFeature() throws {
        // Given
        let core = FeatureRegistrationCoreMock()
        let config = Logs.Configuration()
        Logs.enable(with: config, in: core)

        // When
        let attributeKey: String = .mockRandom()
        let attributeValue: String = .mockRandom()
        Logs.addAttribute(forKey: attributeKey, value: attributeValue, in: core)

        // Then
        let feature = try XCTUnwrap(core.get(feature: LogsFeature.self))
        XCTAssertEqual(feature.attributes.getAttributes()[attributeKey] as? String, attributeValue)
    }

    func testLogsRemoveAttributeForwardedToFeature() throws {
        // Given
        let core = FeatureRegistrationCoreMock()
        let config = Logs.Configuration()
        Logs.enable(with: config, in: core)
        let attributeKey: String = .mockRandom()
        let attributeValue: String = .mockRandom()
        Logs.addAttribute(forKey: attributeKey, value: attributeValue, in: core)

        // When
        Logs.removeAttribute(forKey: attributeKey, in: core)

        // Then
        let feature = try XCTUnwrap(core.get(feature: LogsFeature.self))
        XCTAssertNil(feature.attributes.getAttributes()[attributeKey])
    }

    func testItSendsGlobalLogUpdates_whenAddAttribute() throws {
        // Given
        let mockMessageReceiver = FeatureMessageReceiverMock()
        let core = SingleFeatureCoreMock<LogsFeature>(
            messageReceiver: mockMessageReceiver
        )
        let config = Logs.Configuration()
        Logs.enable(with: config, in: core)

        // When
        let attributeKey: String = .mockRandom()
        let attributeValue: String = .mockRandom()
        Logs.addAttribute(forKey: attributeKey, value: attributeValue, in: core)

        // Then
        let messages = mockMessageReceiver.messages.compactMap { $0.asPayload as? LogEventAttributes }
        XCTAssertEqual(messages.count, 1)
        let message = try XCTUnwrap(messages.first)
        XCTAssertEqual(message.attributes[attributeKey] as? String, attributeValue)
    }

    func testItSendsGlobalLogUpdates_whenRemoveAttribute() throws {
        // Given
        let mockMessageReceiver = FeatureMessageReceiverMock()
        let core = SingleFeatureCoreMock<LogsFeature>(
            messageReceiver: mockMessageReceiver
        )
        let config = Logs.Configuration()
        Logs.enable(with: config, in: core)
        let attributeKey: String = .mockRandom()
        let attributeValue: String = .mockRandom()
        Logs.addAttribute(forKey: attributeKey, value: attributeValue, in: core)

        // When
        Logs.removeAttribute(forKey: attributeKey, in: core)

        // Then
        let messages = mockMessageReceiver.messages.compactMap { $0.asPayload as? LogEventAttributes }
        XCTAssertEqual(messages.count, 2)
        let message = try XCTUnwrap(messages.last)
        XCTAssertNil(message.attributes[attributeKey])
    }
}

// MARK: - Remote configuration

class LogsRemoteConfigurationTests: XCTestCase {
    func testWhenSwitchedOffRemotely_itIsNotEnabled() {
        // Given
        let core = SingleFeatureCoreMock<LogsFeature>()
        core.remoteConfigDocument = .parse(Data(#"{"features":{"logs":false}}"#.utf8))

        // When
        Logs.enable(in: core)

        // Then
        XCTAssertNil(core.get(feature: LogsFeature.self))
    }

    func testRemoteLoggerSettingsOverrideTheInCodeOnes() {
        // Given
        let document = RemoteConfigDocument.parse(Data("""
        {"logs": {"networkInfoEnabled": true, "bundleWithRumEnabled": false, "bundleWithTraceEnabled": false, "remoteSampleRate": 25}}
        """.utf8))
        let configuration = Logger.Configuration(networkInfoEnabled: false, bundleWithRumEnabled: true, bundleWithTraceEnabled: true, remoteSampleRate: 100)

        // When
        let applied = configuration.applying(remoteConfigDocument: document)

        // Then
        XCTAssertTrue(applied.networkInfoEnabled)
        XCTAssertFalse(applied.bundleWithRumEnabled)
        XCTAssertFalse(applied.bundleWithTraceEnabled)
        XCTAssertEqual(applied.remoteSampleRate, 25)
    }

    func testMissingRemoteLoggerSettingsLeaveTheInCodeOnes() {
        let configuration = Logger.Configuration(networkInfoEnabled: true, remoteSampleRate: 50)
        let applied = configuration.applying(remoteConfigDocument: .parse(Data(#"{"logs": {"remoteSampleRate": 150}}"#.utf8)))

        XCTAssertTrue(applied.networkInfoEnabled)
        XCTAssertEqual(applied.remoteSampleRate, 50, "an out of range sample rate is ignored")
    }
}
