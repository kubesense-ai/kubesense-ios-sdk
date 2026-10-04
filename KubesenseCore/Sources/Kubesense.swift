/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import Foundation
@_spi(Internal)
import KubesenseInternal

//swiftlint:disable duplicate_imports
@_exported import enum KubesenseInternal.TrackingConsent
@_exported import protocol KubesenseInternal.KubesenseCoreProtocol
//swiftlint:enable duplicate_imports

/// An entry point to Kubesense SDK.
///
/// Initialize the core instance of the Kubesense SDK prior to enabling any Product.
///
/// ```swift
/// Kubesense.initialize(
///     with: Kubesense.Configuration(clientToken: "<client token>", env: "<environment>"),
///     trackingConsent: .pending
/// )
/// ```
///
/// Once Kubesense SDK is initialized, you can enable products, such as RUM:
///
/// ```swift
/// RUM.enable(
///     with: RUM.Configuration(applicationID: "<application>")
/// )
/// ```
///     
public enum Kubesense {
    /// Verbosity level of Kubesense SDK. Can be used for debugging purposes.
    /// If set, internal events occurring inside SDK will be printed to debugger console if their level is equal or greater than `verbosityLevel`.
    /// Default is `nil`.
    public static var verbosityLevel: CoreLoggerLevel? {
        get { _verbosityLevel.wrappedValue }
        set { _verbosityLevel.wrappedValue = newValue }
    }

    /// The backing storage for `verbosityLevel`, ensuring efficient synchronized
    /// read/write access to the shared value.
    private static let _verbosityLevel = ReadWriteLock<CoreLoggerLevel?>(wrappedValue: nil)

    /// Returns `true` if the Kubesense SDK is already initialized, `false` otherwise.
    ///
    /// - Parameter name: The name of the SDK instance to verify.
    public static func isInitialized(instanceName name: String = CoreRegistry.defaultInstanceName) -> Bool {
        CoreRegistry.instance(named: name) is KubesenseCore
    }

    /// Returns the Kubesense SDK instance for the given name.
    ///
    /// - Parameter name: The name of the instance to get.
    /// - Returns: The core instance if it exists, `NOPKubesenseCore` instance otherwise.
    public static func sdkInstance(named name: String) -> KubesenseCoreProtocol {
        CoreRegistry.instance(named: name)
    }

    /// Sets current user information.
    ///
    /// Those will be added to logs, traces and RUM events automatically.
    ///
    /// - Parameters:
    ///   - id: Mandatory User ID
    ///   - name: Name representing the user, if any
    ///   - email: User's email, if any
    ///   - extraInfo: User's custom attributes, if any
    public static func setUserInfo(
        id: String,
        name: String? = nil,
        email: String? = nil,
        extraInfo: [AttributeKey: AttributeValue] = [:],
        in core: KubesenseCoreProtocol = CoreRegistry.default
    ) {
        let core = core as? KubesenseCore
        core?.setUserInfo(
            id: id,
            name: name,
            email: email,
            extraInfo: extraInfo
        )
    }

    /// Add custom attributes to the current user information
    ///
    /// This extra info will be added to already existing extra info that is added
    /// to  logs traces and RUM events automatically.
    ///
    /// - Parameters:
    ///   - extraInfo: User's additional custom attributes
    public static func addUserExtraInfo(
        _ extraInfo: [AttributeKey: AttributeValue?],
        in core: KubesenseCoreProtocol = CoreRegistry.default
    ) {
        let core = core as? KubesenseCore
        core?.addUserExtraInfo(extraInfo)
    }

    /// Clear the current user information
    ///
    /// User information will be `nil`
    /// Following Logs, Traces, RUM Events will not include the user information anymore
    ///
    /// Any active RUM Session, active RUM View at the time of call will have their `user` attribute emptied
    ///
    /// If you want to retain the current `user` on the active RUM session,
    /// you need to stop the session first by using `RUMMonitor.stopSession()`
    ///
    /// If you want to retain the current `user` on the active RUM views,
    /// you need to stop the view first by using `RUMMonitor.stopView(viewController:attributes:)`
    ///
    public static func clearUserInfo(
        in core: KubesenseCoreProtocol = CoreRegistry.default
    ) {
        let core = core as? KubesenseCore
        core?.clearUserInfo()
    }

    /// Sets current account information.
    ///
    /// Those will be added to logs, traces and RUM events automatically.
    ///
    /// - Parameters:
    ///   - id: Account ID
    ///   - name: Name representing the account, if any
    ///   - extraInfo: Account's custom attributes, if any
    public static func setAccountInfo(
        id: String,
        name: String? = nil,
        extraInfo: [AttributeKey: AttributeValue] = [:],
        in core: KubesenseCoreProtocol = CoreRegistry.default
    ) {
        let core = core as? KubesenseCore
        core?.setAccountInfo(
            id: id,
            name: name,
            extraInfo: extraInfo
        )
    }

    /// Add custom attributes to the current account information
    ///
    /// This extra info will be added to already existing extra info that is added
    /// to logs traces and RUM events automatically.
    ///
    /// - Parameters:
    ///   - extraInfo: User's additional custom attributes
    public static func addAccountExtraInfo(
        _ extraInfo: [AttributeKey: AttributeValue?],
        in core: KubesenseCoreProtocol = CoreRegistry.default
    ) {
        let core = core as? KubesenseCore
        core?.addAccountExtraInfo(extraInfo)
    }

    /// Clear the current account information
    ///
    /// Account information will be `nil`
    /// Following Logs, Traces, RUM Events will not include the account information anymore
    ///
    /// Any active RUM Session, active RUM View at the time of call will have their `account` attribute emptied
    ///
    /// If you want to retain the current `account` on the active RUM session,
    /// you need to stop the session first by using `RUMMonitor.stopSession()`
    ///
    /// If you want to retain the current `account` on the active RUM views,
    /// you need to stop the view first by using `RUMMonitor.stopView(viewController:attributes:)`
    ///
    public static func clearAccountInfo(
        in core: KubesenseCoreProtocol = CoreRegistry.default
    ) {
        let core = core as? KubesenseCore
        core?.clearAccountInfo()
    }

    /// Sets the tracking consent regarding the data collection for the Kubesense SDK.
    /// - Parameter trackingConsent: new consent value, which will be applied for all data collected from now on
    public static func set(trackingConsent: TrackingConsent, in core: KubesenseCoreProtocol = CoreRegistry.default) {
        let core = core as? KubesenseCore
        core?.set(trackingConsent: trackingConsent)
    }

    /// Clears all data that has not already been sent to Kubesense servers.
    public static func clearAllData(in core: KubesenseCoreProtocol = CoreRegistry.default) {
        let core = core as? KubesenseCore
        core?.clearAllData()
    }

    /// Stops the initialized SDK instance attached to the given name.
    ///
    /// Stopping a core instance will stop all current processes by deallocating all Features registered
    /// in the core as well as their storage & upload units.
    /// 
    /// - Parameter instanceName: the name of the instance to stop.
    public static func stopInstance(named instanceName: String = CoreRegistry.defaultInstanceName) {
        let core = CoreRegistry.unregisterInstance(named: instanceName) as? KubesenseCore
        core?.stop()
    }

    /// Initializes the Kubesense SDK.
    ///
    /// You **must** initialize the core instance of the Kubesense SDK prior to enabling any Product.
    ///
    ///    ```swift
    ///     Kubesense.initialize(
    ///         with: Kubesense.Configuration(clientToken: "<client token>", env: "<environment>"),
    ///         trackingConsent: .pending
    ///     )
    ///    ```
    ///
    /// Once Kubesense SDK is initialized, you can enable products, such as RUM:
    ///
    ///    ```swift
    ///     RUM.enable(
    ///         with: RUM.Configuration(applicationID: "<application>")
    ///     )
    ///    ```
    /// It is possible to initialize multiple instances of the SDK, associating them with a name.
    /// Many methods of the SDK can optionally take a SDK instance as an argument. If not provided,
    /// the call will be associated with the default (nameless) SDK instance.
    ///
    /// To use a secondary instance of the SDK, provide a name to the ``initialize`` method
    /// and use the returned instance to enable products:
    ///
    ///    ```swift
    ///     let core = Kubesense.initialize(
    ///         with: Kubesense.Configuration(clientToken: "<client token>", env: "<environment>"),
    ///         trackingConsent: .pending,
    ///         instanceName: "my-instance"
    ///     )
    ///
    ///     RUM.enable(
    ///         with: RUM.Configuration(applicationID: "<application>"),
    ///         in: core
    ///     )
    ///    ```
    ///
    /// - Parameters:
    ///   - configuration: the SDK configuration.
    ///   - trackingConsent: the initial state of the Data Tracking Consent given by the user of the app.
    ///   - instanceName:   The core instance name. This value will be used for data persistency and should be
    ///                     stable between application runs.
    @discardableResult
    public static func initialize(
        with configuration: Configuration,
        trackingConsent: TrackingConsent,
        instanceName: String = CoreRegistry.defaultInstanceName
    ) -> KubesenseCoreProtocol {
        #if targetEnvironment(macCatalyst)
        consolePrint("⚠️ Catalyst is not officially supported by Kubesense SDK: some features may NOT be functional!", .warn)
        #endif

        #if os(macOS)
        consolePrint("⚠️ macOS is not officially supported by Kubesense SDK: some features may NOT be functional!", .warn)
        #endif

        do {
            // To safely instrument the application lifecycle observer and other providers,
            // SDK initialization must occur on the main thread. This enforcement is also present
            // in all Features, ensuring a proper registration order.
            return try runOnMainThreadSync {
                return try initializeOrThrow(
                    with: configuration,
                    trackingConsent: trackingConsent,
                    instanceName: instanceName
                )
            }
        } catch {
            consolePrint("\(error)", .error)
            return NOPKubesenseCore()
        }
    }

    private static func initializeOrThrow(
        with configuration: Configuration,
        trackingConsent: TrackingConsent,
        instanceName: String
    ) throws -> KubesenseCoreProtocol {
        guard !CoreRegistry.isRegistered(instanceName: instanceName) else {
            throw ProgrammerError(description: "The '\(instanceName)' instance of SDK is already initialized.")
        }

        registerObjcExceptionHandlerOnce()

        try isValid(clientToken: configuration.clientToken)
        try isValid(env: configuration.env)

        let core = try KubesenseCore(
            configuration: configuration,
            trackingConsent: trackingConsent,
            instanceName: instanceName
        )

        CITestIntegration.active?.startIntegration()

        CoreRegistry.register(core, named: instanceName)

        deleteV1Folders(in: core)

        DD.logger = InternalLogger(
            dateProvider: configuration.dateProvider,
            timeZone: .current,
            printFunction: consolePrint,
            verbosityLevel: { Kubesense.verbosityLevel }
        )

        return core
    }

    private static func deleteV1Folders(in core: KubesenseCore) {
        let deprecated = ["ai.kubesense.logs", "ai.kubesense.traces", "ai.kubesense.rum"].compactMap {
            try? Directory.cache().subdirectory(path: $0) // ignore errors - deprecated paths likely do not exist
        }

        core.readWriteQueue.async {
            // ignore errors
            deprecated.forEach { try? FileManager.default.removeItem(at: $0.url) }
        }
    }

    /// Flushes all authorised data for each feature, tears down and deinitializes the SDK.
    /// - It flushes all data authorised for each feature by performing its arbitrary upload (without retrying).
    /// - It completes all pending asynchronous work in each feature.
    ///
    /// This is highly experimental API and only supported in tests.
#if KUBESENSE_SDK_COMPILED_FOR_TESTING
    public static func flushAndDeinitialize(instanceName: String = CoreRegistry.defaultInstanceName) {
        internalFlushAndDeinitialize(instanceName: instanceName)
    }
#endif

    internal static func internalFlushAndDeinitialize(instanceName: String = CoreRegistry.defaultInstanceName) {
        // Unregister core instance:
        let core = CoreRegistry.unregisterInstance(named: instanceName) as? KubesenseCore
        // Flush and tear down SDK core:
        core?.flushAndTearDown()
    }
}

@_spi(Internal)
public extension Kubesense {
    /// Forces all pending data to upload to intake immediately. Blocks the calling thread until complete.
    /// The SDK remains fully operational after this call.
    ///
    /// - Parameter instanceName: The name of the SDK instance to flush.
    static func flush(instanceName: String = CoreRegistry.defaultInstanceName) {
        guard let core = CoreRegistry.instance(named: instanceName) as? KubesenseCore else {
            return
        }
        core.flushAndUpload()
    }
}

private func isValid(env: String) throws {
    /// 1. cannot be more than 200 chars (including `env:` prefix)
    /// 2. cannot end with `:`
    /// 3. can contain letters, numbers and _:./-_ (other chars are converted to _ at backend)
    let regex = #"^[a-zA-Z0-9_:./-]{0,195}[a-zA-Z0-9_./-]$"#
    if env.range(of: regex, options: .regularExpression, range: nil, locale: nil) == nil {
        throw ProgrammerError(description: "`env`: \(env) contains illegal characters (only alphanumerics and `_` are allowed)")
    }
}

private func isValid(clientToken: String) throws {
    if clientToken.isEmpty {
        throw ProgrammerError(description: "`clientToken` cannot be empty.")
    }
}

extension KubesenseCore {
    /// The primary entry point for creating a `KubesenseCore` instance.
    ///
    /// - Parameters:
    ///   - configuration: A configuration object that encapsulates both user-defined options and internal dependencies
    ///     passed to SDK's downstream components.
    ///   - trackingConsent: The user's consent regarding data tracking for the SDK.
    ///   - instanceName: A unique name for this SDK instance.
    convenience init(
        configuration: Kubesense.Configuration,
        trackingConsent: TrackingConsent,
        instanceName: String
    ) throws {
        let debug = configuration.processInfo.arguments.contains(LaunchArguments.Debug)
        if debug {
            consolePrint("⚠️ Overriding verbosity, upload frequency, and sample rates due to \(LaunchArguments.Debug) launch argument", .warn)
            Kubesense.verbosityLevel = .debug
        }

        let applicationVersion = configuration.additionalConfiguration[CrossPlatformAttributes.version] as? String
            ?? configuration.version
            ?? configuration.bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? configuration.bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? "0.0.0"

        let applicationBuildNumber = configuration.bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? "0"

        let bundleName = configuration.bundle.object(forInfoDictionaryKey: "CFBundleExecutable") as? String
        let bundleType = BundleType(bundle: configuration.bundle)
        let bundleIdentifier = configuration.bundle.bundleIdentifier ?? "unknown"
        let service = configuration.service ?? configuration.bundle.bundleIdentifier ?? "ios"
        let source = configuration.additionalConfiguration[CrossPlatformAttributes.ksource] as? String ?? "ios"
        let variant = configuration.additionalConfiguration[CrossPlatformAttributes.variant] as? String
        let sdkVersion = configuration.additionalConfiguration[CrossPlatformAttributes.sdkVersion] as? String ?? __sdkVersion
        let buildId = configuration.additionalConfiguration[CrossPlatformAttributes.buildId] as? String
        let nativeSourceType = configuration.additionalConfiguration[CrossPlatformAttributes.nativeSourceType] as? String

        let httpClient = configuration.httpClientFactory(configuration.proxyConfiguration)
        // Every feature uploads to this single collector: the configured `kubesenseRumEndpoint`, or the site's.
        let intakeEndpoint = configuration.kubesenseRumEndpointURL ?? configuration.site.endpoint

        // Load the dashboard-managed configuration before anything reads the core settings: it can
        // override the upload pipeline, and features consult it as they are enabled.
        let remoteConfigurationProvider: RemoteConfigurationProvider?
        if configuration.remoteConfigurationEnabled {
            // Remote configuration must survive `/Library/Caches` purges, so it is stored under
            // `/Library/Application Support` instead of the (purgeable) core directory.
            let persistentDirectory = try CoreDirectory(
                in: configuration.persistentDirectory(),
                instanceName: instanceName,
                site: configuration.site
            )
            remoteConfigurationProvider = RemoteConfigurationProvider(
                endpoint: intakeEndpoint,
                clientToken: configuration.clientToken,
                directory: persistentDirectory.coreDirectory,
                httpClient: httpClient,
                notificationCenter: configuration.notificationCenter,
                refreshPeriod: configuration.remoteConfigurationRefreshPeriod,
                dateProvider: configuration.dateProvider
            )
        } else {
            remoteConfigurationProvider = nil
        }
        let remoteConfigDocument = remoteConfigurationProvider?.readCachedDocument() ?? .empty
        // Only values the document carries are applied. The endpoint, client token and environment are what
        // the configuration request itself relies on, so they stay under the application's control.
        let batchSize = remoteConfigDocument.enumValue(RemoteConfigSection.core, "batchSize", [
            "SMALL": Kubesense.Configuration.BatchSize.small,
            "MEDIUM": .medium,
            "LARGE": .large,
        ]) ?? configuration.batchSize
        let uploadFrequency = remoteConfigDocument.enumValue(RemoteConfigSection.core, "uploadFrequency", [
            "FREQUENT": Kubesense.Configuration.UploadFrequency.frequent,
            "AVERAGE": .average,
            "RARE": .rare,
        ]) ?? configuration.uploadFrequency

        let performance = PerformancePreset(
            batchSize: debug ? .small : batchSize,
            uploadFrequency: debug ? .frequent : uploadFrequency,
            bundleType: bundleType,
            batchProcessingLevel: configuration.batchProcessingLevel
        )
        let isRunFromExtension = bundleType == .iOSAppExtension

        let directory = try CoreDirectory(
            in: configuration.systemDirectory(),
            instanceName: instanceName,
            site: configuration.site
        )

        self.init(
            directory: directory,
            dateProvider: configuration.dateProvider,
            initialConsent: trackingConsent,
            performance: performance,
            httpClient: httpClient,
            encryption: configuration.encryption,
            contextProvider: KubesenseContextProvider(
                site: configuration.site,
                intakeEndpoint: intakeEndpoint,
                clientToken: configuration.clientToken,
                service: service,
                env: configuration.env,
                version: applicationVersion,
                buildNumber: applicationBuildNumber,
                buildId: buildId,
                variant: variant,
                source: source,
                nativeSourceOverride: nativeSourceType,
                sdkVersion: sdkVersion,
                ciAppOrigin: CITestIntegration.active?.origin,
                applicationName: bundleName ?? bundleType.rawValue,
                applicationBundleIdentifier: bundleIdentifier,
                applicationBundleType: bundleType,
                applicationVersion: applicationVersion,
                sdkInitDate: configuration.dateProvider.now,
                device: DeviceInfo(processInfo: configuration.processInfo),
                os: OperatingSystem(),
                locale: LocaleInfo(),
                processInfo: configuration.processInfo,
                dateProvider: configuration.dateProvider,
                serverDateProvider: configuration.serverDateProvider,
                notificationCenter: configuration.notificationCenter,
                appLaunchHandler: configuration.appLaunchHandler,
                appStateProvider: configuration.appStateProvider,
                remoteConfigurationId: nil
            ),
            applicationVersion: applicationVersion,
            maxBatchesPerUpload: configuration.batchProcessingLevel.maxBatchesPerUpload,
            backgroundTasksEnabled: configuration.backgroundTasksEnabled,
            isRunFromExtension: isRunFromExtension,
            remoteConfigurationProvider: remoteConfigurationProvider,
            remoteConfigDocument: remoteConfigDocument
        )

        telemetry.configuration(
            backgroundTasksEnabled: configuration.backgroundTasksEnabled,
            batchProcessingLevel: Int64(exactly: configuration.batchProcessingLevel.maxBatchesPerUpload),
            batchSize: performance.uploaderWindow.dd.toInt64Milliseconds,
            batchUploadFrequency: performance.minUploadDelay.dd.toInt64Milliseconds,
            useLocalEncryption: configuration.encryption != nil,
            useProxy: configuration.proxyConfiguration != nil
        )
    }
}
