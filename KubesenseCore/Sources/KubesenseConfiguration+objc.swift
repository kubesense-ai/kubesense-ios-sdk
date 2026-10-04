/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import Foundation
import KubesenseInternal

@objc(KubesenseSite)
@objcMembers
@_spi(objc)
public final class objc_KubesenseSite: NSObject {
    internal let sdkSite: KubesenseSite

    internal init(sdkSite: KubesenseSite) {
        self.sdkSite = sdkSite
    }

    // MARK: - Public

    /// The production site: `us2.kubesense.ai`.
    public static func prod() -> objc_KubesenseSite { .init(sdkSite: .prod) }

    /// The staging site (internal usage only): `dev.kubesense.ai`.
    public static func staging() -> objc_KubesenseSite { .init(sdkSite: .staging) }
}

@objc(KubesenseBatchSize)
@_spi(objc)
public enum objc_BatchSize: Int {
    case small
    case medium
    case large

    internal var swiftType: Kubesense.Configuration.BatchSize {
        switch self {
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        }
    }

    internal init(swiftType: Kubesense.Configuration.BatchSize) {
        switch swiftType {
        case .small: self = .small
        case .medium: self = .medium
        case .large: self = .large
        }
    }
}

@objc(KubesenseUploadFrequency)
@_spi(objc)
public enum objc_UploadFrequency: Int {
    case frequent
    case average
    case rare

    internal var swiftType: Kubesense.Configuration.UploadFrequency {
        switch self {
        case .frequent: return .frequent
        case .average: return .average
        case .rare: return .rare
        }
    }

    internal init(swiftType: Kubesense.Configuration.UploadFrequency) {
        switch swiftType {
        case .frequent: self = .frequent
        case .average: self = .average
        case .rare: self = .rare
        }
    }
}

@objc(KubesenseBatchProcessingLevel)
@_spi(objc)
public enum objc_BatchProcessingLevel: Int {
    case low
    case medium
    case high

    internal var swiftType: Kubesense.Configuration.BatchProcessingLevel {
        switch self {
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        }
    }

    internal init(swiftType: Kubesense.Configuration.BatchProcessingLevel) {
        switch swiftType {
        case .low: self = .low
        case .medium: self = .medium
        case .high: self = .high
        }
    }
}

@objc(KubesenseDataEncryption)
@_spi(objc)
public protocol objc_DataEncryption: AnyObject {
    /// Encrypts given `Data` with user-chosen encryption.
    ///
    /// - Parameter data: Data to encrypt.
    /// - Returns: The encrypted data.
    func encrypt(data: Data) throws -> Data

    /// Decrypts given `Data` with user-chosen encryption.
    ///
    /// Beware that data to decrypt could be encrypted in a previous
    /// app launch, so implementation should be aware of the case when decryption could
    /// fail (for example, key used for encryption is different from key used for decryption, if
    /// they are unique for every app launch).
    ///
    /// - Parameter data: Data to decrypt.
    /// - Returns: The decrypted data.
    func decrypt(data: Data) throws -> Data
}

internal struct KubesenseDataEncryptionBridge: DataEncryption {
    let objcEncryption: objc_DataEncryption

    func encrypt(data: Data) throws -> Data {
        return try objcEncryption.encrypt(data: data)
    }

    func decrypt(data: Data) throws -> Data {
        return try objcEncryption.decrypt(data: data)
    }
}

@objc(KubesenseServerDateProvider)
@_spi(objc)
public protocol objc_ServerDateProvider: AnyObject {
    /// Start the clock synchronisation with NTP server.
    ///
    /// Calls the `completion` by passing it the server time offset when the synchronization succeeds or`nil` if it fails.
    func synchronize(update: @escaping (TimeInterval) -> Void)
}

internal struct KubesenseServerDateProviderBridge: ServerDateProvider {
    let objcProvider: objc_ServerDateProvider

    func synchronize(update: @escaping (TimeInterval) -> Void) {
        objcProvider.synchronize(update: update)
    }
}

@objc(KubesenseConfiguration)
@objcMembers
@_spi(objc)
public final class objc_Configuration: NSObject {
    internal var sdkConfiguration: Kubesense.Configuration

    /// Either the RUM client token (which supports RUM, Logging and APM) or regular client token, only for Logging and APM.
    public var clientToken: String {
        get { sdkConfiguration.clientToken }
        set { sdkConfiguration.clientToken = newValue }
    }

    /// The environment name which will be sent to Kubesense. This can be used
    /// To filter events on different environments (e.g. "staging" or "production").
    public var env: String {
        get { sdkConfiguration.env }
        set { sdkConfiguration.env = newValue }
    }

    /// The Kubesense site where data is sent.
    ///
    /// Default value is `.prod`.
    public var site: objc_KubesenseSite {
        get { objc_KubesenseSite(sdkSite: sdkConfiguration.site) }
        set { sdkConfiguration.site = newValue.sdkSite }
    }

    /// The host of a Kubesense RUM collector every feature uploads to, instead of the one of `site`.
    /// A scheme or a path in the value is ignored: data is always uploaded over https.
    ///
    /// Default value is `nil`.
    public var kubesenseRumEndpoint: String? {
        get { sdkConfiguration.kubesenseRumEndpoint }
        set { sdkConfiguration.kubesenseRumEndpoint = newValue }
    }

    /// The service name associated with data send to Kubesense.
    ///
    /// Default value is set to application bundle identifier.
    public var service: String? {
        get { sdkConfiguration.service }
        set { sdkConfiguration.service = newValue }
    }

    /// The application version used for Unified Service Tagging.
    ///
    /// If not provided, the SDK will use the version from the application's Info.plist
    /// (`CFBundleShortVersionString` or `CFBundleVersion`).
    public var version: String? {
        get { sdkConfiguration.version }
        set { sdkConfiguration.version = newValue }
    }

    /// The preferred size of batched data uploaded to Kubesense servers.
    /// This value impacts the size and number of requests performed by the SDK.
    ///
    /// `.medium` by default.
    public var batchSize: objc_BatchSize {
        get { objc_BatchSize(swiftType: sdkConfiguration.batchSize) }
        set { sdkConfiguration.batchSize = newValue.swiftType }
    }

    /// The preferred frequency of uploading data to Kubesense servers.
    /// This value impacts the frequency of performing network requests by the SDK.
    ///
    /// `.average` by default.
    public var uploadFrequency: objc_UploadFrequency {
        get { objc_UploadFrequency(swiftType: sdkConfiguration.uploadFrequency) }
        set { sdkConfiguration.uploadFrequency = newValue.swiftType }
    }

    /// 
    public var batchProcessingLevel: objc_BatchProcessingLevel {
        get { objc_BatchProcessingLevel(swiftType: sdkConfiguration.batchProcessingLevel) }
        set { sdkConfiguration.batchProcessingLevel = newValue.swiftType }
    }

    /// Proxy configuration attributes.
    /// This can be used to a enable a custom proxy for uploading tracked data to Kubesense's intake.
    public var proxyConfiguration: [AnyHashable: Any]? {
        get { sdkConfiguration.proxyConfiguration }
        set { sdkConfiguration.proxyConfiguration = newValue }
    }

    /// Sets Data encryption to use for on-disk data persistency by providing an object
    /// complying with `DataEncryption` protocol.
    public func setEncryption(_ encryption: objc_DataEncryption) {
        sdkConfiguration.encryption = KubesenseDataEncryptionBridge(objcEncryption: encryption)
    }

    /// A custom NTP synchronization interface.
    ///
    /// By default, the Kubesense SDK synchronizes with dedicated NTP pools provided by the
    /// https://www.ntppool.org/ . Using different pools or setting a no-op `ServerDateProvider`
    /// implementation will result in desynchronization of the SDK instance and the Kubesense servers.
    /// This can lead to significant time shift in RUM sessions or distributed traces.
    public func setServerDateProvider(_ serverDateProvider: objc_ServerDateProvider) {
        sdkConfiguration.serverDateProvider = KubesenseServerDateProviderBridge(objcProvider: serverDateProvider)
    }

    /// The bundle object that contains the current executable.
    public var bundle: Bundle {
        get { sdkConfiguration.bundle }
        set { sdkConfiguration.bundle = newValue }
    }

    /// Sets additional configuration attributes.
    /// This can be used to tweak internal features of the SDK and shouldn't be considered as a part of public API.
    public var additionalConfiguration: [String: Any] {
        get { sdkConfiguration._internal.additionalConfiguration }
        set { sdkConfiguration._internal_mutation { $0.additionalConfiguration = newValue } }
    }

    /// Flag that determines if UIApplication methods [`beginBackgroundTask(expirationHandler:)`](https://developer.apple.com/documentation/uikit/uiapplication/1623031-beginbackgroundtaskwithexpiratio) and [`endBackgroundTask:`](https://developer.apple.com/documentation/uikit/uiapplication/1622970-endbackgroundtask)
    /// are utilized to perform background uploads. It may extend the amount of time the app is operating in background by 30 seconds.
    ///
    /// Tasks are normally stopped when there's nothing to upload or when encountering any upload blocker such us no internet connection or low battery.
    ///
    /// `false` by default.
    public var backgroundTasksEnabled: Bool {
        get { sdkConfiguration.backgroundTasksEnabled }
        set { sdkConfiguration.backgroundTasksEnabled = newValue }
    }

    /// Controls dashboard-managed remote configuration: the document cached by the previous launch is
    /// applied at initialization, and a fresh one is fetched in the background for the next launch.
    ///
    /// `true` by default.
    public var remoteConfigurationEnabled: Bool {
        get { sdkConfiguration.remoteConfigurationEnabled }
        set { sdkConfiguration.remoteConfigurationEnabled = newValue }
    }

    /// How often, in seconds, the SDK re-fetches the remote configuration. Values below one minute are
    /// raised to one minute; zero or less disables the periodic refresh.
    ///
    /// Six hours by default.
    public var remoteConfigurationRefreshPeriod: TimeInterval {
        get { sdkConfiguration.remoteConfigurationRefreshPeriod }
        set { sdkConfiguration.remoteConfigurationRefreshPeriod = newValue }
    }

    /// Creates a Kubesense SDK Configuration object.
    ///
    /// - Parameters:
    ///   - clientToken:    Either the RUM client token (which supports RUM, Logging and APM) or regular client token,
    ///                     only for Logging and APM.
    ///
    ///   - env:    The environment name which will be sent to Kubesense. This can be used
    ///             To filter events on different environments (e.g. "staging" or "production").
    public init(clientToken: String, env: String) {
        sdkConfiguration = .init(clientToken: clientToken, env: env)
    }
}
