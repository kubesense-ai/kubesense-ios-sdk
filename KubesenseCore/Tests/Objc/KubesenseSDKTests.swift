/*
* Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
* This product includes software developed at Datadog (https://www.datadoghq.com/).
* Copyright 2019-Present Datadog, Inc.
*/

import XCTest
import TestUtilities

@testable import KubesenseInternal
@testable import KubesenseLogs
@_spi(objc)
@testable import KubesenseCore

/// These tests verify that Objc APIs properly interact with`Kubesense` public API (swift).
class KubesenseSDKTests: XCTestCase {
    override func setUp() {
        super.setUp()
        XCTAssertFalse(Kubesense.isInitialized())
    }

    override func tearDown() {
        XCTAssertFalse(Kubesense.isInitialized())
        super.tearDown()
    }

    // MARK: - SDK initialization / stop lifecycle

    func testItForwardsInitializationToSwift() throws {
        let config = objc_Configuration(
            clientToken: "abcefghi",
            env: "tests"
        )

        config.bundle = .mockWith(CFBundleExecutable: "app-name")

        objc_Kubesense.initialize(
            configuration: config,
            trackingConsent: randomConsent().objc
        )

        XCTAssertTrue(Kubesense.isInitialized())

        let context = try XCTUnwrap(CoreRegistry.default as? KubesenseCore).contextProvider.read()
        XCTAssertEqual(context.applicationName, "app-name")
        XCTAssertEqual(context.env, "tests")

        Kubesense.flushAndDeinitialize()

        XCTAssertNil(CoreRegistry.default.get(feature: LogsFeature.self))
    }

    func testItReflectsInitializationStatus() throws {
        let config = objc_Configuration(
            clientToken: "abcefghi",
            env: "tests"
        )

        config.bundle = .mockWith(CFBundleExecutable: "app-name")
        XCTAssertFalse(objc_Kubesense.isInitialized())

        objc_Kubesense.initialize(
            configuration: config,
            trackingConsent: randomConsent().objc
        )

        XCTAssertTrue(objc_Kubesense.isInitialized())

        Kubesense.flushAndDeinitialize()

        XCTAssertNil(CoreRegistry.default.get(feature: LogsFeature.self))
    }

    func testItForwardsStopInstanceToSwift() throws {
        let config = objc_Configuration(
            clientToken: "abcefghi",
            env: "tests"
        )

        config.bundle = .mockWith(CFBundleExecutable: "app-name")

        objc_Kubesense.initialize(
            configuration: config,
            trackingConsent: randomConsent().objc
        )

        XCTAssertTrue(Kubesense.isInitialized())

        objc_Kubesense.stopInstance()

        XCTAssertFalse(Kubesense.isInitialized())

        XCTAssertNil(CoreRegistry.default.get(feature: LogsFeature.self))
    }

    // MARK: - Changing Tracking Consent

    func testItForwardsTrackingConsentToSwift() {
        let initialConsent = randomConsent()
        let nextConsent = randomConsent()

        objc_Kubesense.initialize(
            configuration: objc_Configuration(clientToken: "abcefghi", env: "tests"),
            trackingConsent: initialConsent.objc
        )

        let core = CoreRegistry.default as? KubesenseCore
        XCTAssertEqual(core?.consentPublisher.consent, initialConsent.swift)

        objc_Kubesense.setTrackingConsent(consent: nextConsent.objc)

        XCTAssertEqual(core?.consentPublisher.consent, nextConsent.swift)

        Kubesense.flushAndDeinitialize()
    }

    // MARK: - Setting user info

    func testItForwardsUserInfoToSwift() throws {
        objc_Kubesense.initialize(
            configuration: objc_Configuration(clientToken: "abcefghi", env: "tests"),
            trackingConsent: randomConsent().objc
        )

        let core = CoreRegistry.default as? KubesenseCore
        let userInfo = try XCTUnwrap(core?.userInfoPublisher)

        objc_Kubesense.setUserInfo(
            userId: "id",
            name: "name",
            email: "email",
            extraInfo: [
                "attribute-int": 42,
                "attribute-double": 42.5,
                "attribute-string": "string value"
            ]
        )
        objc_Kubesense.addUserExtraInfo(["foo": "bar"])
        XCTAssertEqual(userInfo.current.id, "id")
        XCTAssertEqual(userInfo.current.name, "name")
        XCTAssertEqual(userInfo.current.email, "email")
        let extraInfo = userInfo.current.extraInfo
        XCTAssertEqual(extraInfo["attribute-int"]?.kubesense.decode(), 42)
        XCTAssertEqual(extraInfo["attribute-double"]?.kubesense.decode(), 42.5)
        XCTAssertEqual(extraInfo["attribute-string"]?.kubesense.decode(), "string value")
        XCTAssertEqual(extraInfo["foo"]?.kubesense.decode(), "bar")

        objc_Kubesense.setUserInfo(userId: "id", name: nil, email: nil, extraInfo: [:])
        XCTAssertNotNil(userInfo.current.id)
        XCTAssertNil(userInfo.current.name)
        XCTAssertNil(userInfo.current.email)
        XCTAssertTrue(userInfo.current.extraInfo.isEmpty)

        Kubesense.flushAndDeinitialize()
    }

    // MARK: - Changing SDK verbosity level

    private let swiftVerbosityLevels: [CoreLoggerLevel?] = [
        .debug, .warn, .error, .critical, nil
    ]
    private let objcVerbosityLevels: [objc_CoreLoggerLevel] = [
        .debug, .warn, .error, .critical, .none
    ]

    func testItForwardsSettingVerbosityLevelToSwift() {
        defer { Kubesense.verbosityLevel = nil }

        zip(swiftVerbosityLevels, objcVerbosityLevels).forEach { swiftLevel, objcLevel in
            objc_Kubesense.setVerbosityLevel(objcLevel)
            XCTAssertEqual(Kubesense.verbosityLevel, swiftLevel)
        }
    }

    func testItGetsVerbosityLevelFromSwift() {
        defer { Kubesense.verbosityLevel = nil }

        zip(swiftVerbosityLevels, objcVerbosityLevels).forEach { swiftLevel, objcLevel in
            Kubesense.verbosityLevel = swiftLevel
            XCTAssertEqual(objc_Kubesense.verbosityLevel(), objcLevel)
        }
    }

    // MARK: - Helpers

    private func randomConsent() -> (objc: objc_TrackingConsent, swift: TrackingConsent) {
        let objcConsents: [objc_TrackingConsent] = [.granted(), .notGranted(), .pending()]
        let swiftConsents: [TrackingConsent] = [.granted, .notGranted, .pending]
        let index: Int = .random(in: 0..<3)
        return (objc: objcConsents[index], swift: swiftConsents[index])
    }
}
