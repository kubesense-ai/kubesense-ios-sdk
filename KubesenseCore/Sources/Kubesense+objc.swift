/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import Foundation
@_spi(objc)
import KubesenseInternal

@objc(KubesenseTrackingConsent)
@objcMembers
@_spi(objc)
public final class objc_TrackingConsent: NSObject {
    internal let sdkConsent: TrackingConsent

    internal init(sdkConsent: TrackingConsent) {
        self.sdkConsent = sdkConsent
    }

    // MARK: - Public

    public static func granted() -> objc_TrackingConsent { .init(sdkConsent: .granted) }

    public static func notGranted() -> objc_TrackingConsent { .init(sdkConsent: .notGranted) }

    public static func pending() -> objc_TrackingConsent { .init(sdkConsent: .pending) }
}

@objc(KubesenseSDK)
@objcMembers
@_spi(objc)
public final class objc_Kubesense: NSObject {
    // MARK: - Public

    public static func initialize(
        configuration: objc_Configuration,
        trackingConsent: objc_TrackingConsent
    ) {
        Kubesense.initialize(
            with: configuration.sdkConfiguration,
            trackingConsent: trackingConsent.sdkConsent
        )
    }

    public static func initialize(
        configuration: objc_Configuration,
        trackingConsent: objc_TrackingConsent,
        instanceName: String
    ) {
        Kubesense.initialize(
            with: configuration.sdkConfiguration,
            trackingConsent: trackingConsent.sdkConsent,
            instanceName: instanceName
        )
    }

    public static func setVerbosityLevel(_ verbosityLevel: objc_CoreLoggerLevel) {
        switch verbosityLevel {
        case .debug: Kubesense.verbosityLevel = .debug
        case .warn: Kubesense.verbosityLevel = .warn
        case .error: Kubesense.verbosityLevel = .error
        case .critical: Kubesense.verbosityLevel = .critical
        case .none: Kubesense.verbosityLevel = nil
        }
    }

    public static func verbosityLevel() -> objc_CoreLoggerLevel {
        switch Kubesense.verbosityLevel {
        case .debug: return .debug
        case .warn: return .warn
        case .error: return .error
        case .critical: return .critical
        case .none: return .none
        }
    }

    public static func setUserInfo(userId: String, name: String? = nil, email: String? = nil, extraInfo: [String: Any] = [:]) {
        Kubesense.setUserInfo(id: userId, name: name, email: email, extraInfo: extraInfo.dd.swiftAttributes)
    }

    public static func setUserInfo(userId: String, instanceName: String?, name: String? = nil, email: String? = nil, extraInfo: [String: Any] = [:]) {
        Kubesense.setUserInfo(id: userId, name: name, email: email, extraInfo: extraInfo.dd.swiftAttributes, in: CoreRegistry.instance(named: instanceName ?? CoreRegistry.defaultInstanceName))
    }

    public static func clearUserInfo() {
        Kubesense.clearUserInfo()
    }

    public static func clearUserInfo(instanceName: String?) {
        Kubesense.clearUserInfo(in: CoreRegistry.instance(named: instanceName ?? CoreRegistry.defaultInstanceName))
    }

    public static func addUserExtraInfo(_ extraInfo: [String: Any]) {
        Kubesense.addUserExtraInfo(extraInfo.dd.swiftAttributes)
    }

    public static func addUserExtraInfo(_ extraInfo: [String: Any], instanceName: String?) {
        Kubesense.addUserExtraInfo(extraInfo.dd.swiftAttributes, in: CoreRegistry.instance(named: instanceName ?? CoreRegistry.defaultInstanceName))
    }

    public static func setAccountInfo(accountId: String, name: String? = nil, extraInfo: [String: Any] = [:]) {
        Kubesense.setAccountInfo(id: accountId, name: name, extraInfo: extraInfo.dd.swiftAttributes)
    }

    public static func setAccountInfo(accountId: String, instanceName: String?, name: String? = nil, extraInfo: [String: Any] = [:]) {
        Kubesense.setAccountInfo(id: accountId, name: name, extraInfo: extraInfo.dd.swiftAttributes, in: CoreRegistry.instance(named: instanceName ?? CoreRegistry.defaultInstanceName))
    }

    public static func addAccountExtraInfo(_ extraInfo: [String: Any]) {
        Kubesense.addAccountExtraInfo(extraInfo.dd.swiftAttributes)
    }

    public static func addAccountExtraInfo(_ extraInfo: [String: Any], instanceName: String?) {
        Kubesense.addAccountExtraInfo(extraInfo.dd.swiftAttributes, in: CoreRegistry.instance(named: instanceName ?? CoreRegistry.defaultInstanceName))
    }

    public static func clearAccountInfo() {
        Kubesense.clearAccountInfo()
    }

    public static func clearAccountInfo(instanceName: String?) {
        Kubesense.clearAccountInfo(in: CoreRegistry.instance(named: instanceName ?? CoreRegistry.defaultInstanceName))
    }

    public static func setTrackingConsent(consent: objc_TrackingConsent) {
        Kubesense.set(trackingConsent: consent.sdkConsent)
    }

    public static func setTrackingConsent(consent: objc_TrackingConsent, instanceName: String?) {
        Kubesense.set(trackingConsent: consent.sdkConsent, in: CoreRegistry.instance(named: instanceName ?? CoreRegistry.defaultInstanceName))
    }

    public static func isInitialized() -> Bool {
        return Kubesense.isInitialized()
    }

    public static func isInitialized(instanceName: String?) -> Bool {
        return Kubesense.isInitialized(instanceName: instanceName ?? CoreRegistry.defaultInstanceName)
    }

    public static func stopInstance() {
        Kubesense.stopInstance()
    }

    public static func stopInstance(instanceName: String?) {
        Kubesense.stopInstance(named: instanceName ?? CoreRegistry.defaultInstanceName)
    }

    public static func clearAllData() {
        Kubesense.clearAllData()
    }

    public static func clearAllData(instanceName: String?) {
        Kubesense.clearAllData(in: CoreRegistry.instance(named: instanceName ?? CoreRegistry.defaultInstanceName))
    }

#if KUBESENSE_SDK_COMPILED_FOR_TESTING
    public static func flushAndDeinitialize() {
        Kubesense.flushAndDeinitialize()
    }

    public static func flushAndDeinitialize(instanceName: String?) {
        Kubesense.flushAndDeinitialize(instanceName: instanceName ?? CoreRegistry.defaultInstanceName)
    }
#endif
}
