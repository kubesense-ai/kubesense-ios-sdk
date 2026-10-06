/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import Foundation
import KubesenseInternal

@_exported import class KubesenseInternal.CoreRegistry
@_exported import class KubesenseInternal.HTTPHeadersWriter
@_exported import class KubesenseInternal.B3HTTPHeadersWriter
@_exported import class KubesenseInternal.W3CHTTPHeadersWriter

extension Kubesense {
    /// Configuration of Kubesense SDK.
    public struct Configuration {
        /// Defines the Kubesense SDK policy when batching data together before uploading it to Kubesense servers.
        /// Smaller batches mean smaller but more network requests, whereas larger batches mean fewer but larger network requests.
        public enum BatchSize: CaseIterable {
            /// Prefer small sized data batches.
            case small
            /// Prefer medium sized data batches.
            case medium
            /// Prefer large sized data batches.
            case large
        }

        /// Defines the frequency at which Kubesense SDK will try to upload data batches.
        public enum UploadFrequency: CaseIterable {
            /// Try to upload batched data frequently.
            case frequent
            /// Try to upload batched data with a medium frequency.
            case average
            /// Try to upload batched data rarely.
            case rare
        }

        /// Defines the maximum amount of batches processed sequentially without a delay within one reading/uploading cycle.
        public enum BatchProcessingLevel: CaseIterable {
            case low
            case medium
            case high

            var maxBatchesPerUpload: Int {
                switch self {
                case .low:
                    return 5
                case .medium:
                    return 20
                case .high:
                    return 100
                }
            }
        }

        /// Either the RUM client token (which supports RUM, Logging and APM) or regular client token, only for Logging and APM.
        public var clientToken: String

        /// The environment name which will be sent to Kubesense. This can be used
        /// To filter events on different environments (e.g. "staging" or "production").
        public var env: String

        /// The Kubesense site where data is sent.
        ///
        /// Default value is `.prod` (`us2.kubesense.ai`).
        public var site: KubesenseSite

        /// The host of a Kubesense RUM collector to send data to, instead of the one of `site`.
        ///
        /// All features (RUM, Logs, Traces, Session Replay, Profiling, Flags) upload to this single host.
        /// The value must be a host, with an optional port, e.g. `intake.example.com` or
        /// `intake.example.com:8443`. A scheme or a path in the value is ignored: data is always uploaded
        /// over https, to `https://<host>/rum/api/v1/...`.
        ///
        /// Default value is `nil`: data is sent to the collector of `site`.
        public var kubesenseRumEndpoint: String?

        /// The service name associated with data send to Kubesense.
        ///
        /// Default value is set to application bundle identifier.
        public var service: String?

        /// The application version used for Unified Service Tagging.
        ///
        /// If not provided, the SDK will use the version from the application's Info.plist
        /// (`CFBundleShortVersionString` or `CFBundleVersion`).
        public var version: String?

        /// The preferred size of batched data uploaded to Kubesense servers.
        /// This value impacts the size and number of requests performed by the SDK.
        ///
        /// `.medium` by default.
        public var batchSize: BatchSize

        /// The preferred frequency of uploading data to Kubesense servers.
        /// This value impacts the frequency of performing network requests by the SDK.
        ///
        /// `.average` by default.
        public var uploadFrequency: UploadFrequency

        /// Proxy configuration attributes.
        /// This can be used to a enable a custom proxy for uploading tracked data to Kubesense's intake.
        ///
        /// Ref.: https://developer.apple.com/documentation/foundation/urlsessionconfiguration/1411499-connectionproxydictionary
        public var proxyConfiguration: [AnyHashable: Any]?

        /// SeData encryption to use for on-disk data persistency by providing an object
        /// complying with `DataEncryption` protocol.
        public var encryption: DataEncryption?

        /// A custom NTP synchronization interface.
        ///
        /// By default, the Kubesense SDK synchronizes with dedicated NTP pools provided by the
        /// https://www.ntppool.org/ . Using different pools or setting a no-op `ServerDateProvider`
        /// implementation will result in desynchronization of the SDK instance and the Kubesense servers.
        /// This can lead to significant time shift in RUM sessions or distributed traces.
        public var serverDateProvider: ServerDateProvider

        /// The bundle object that contains the current executable.
        public var bundle: Bundle

        /// Batch provessing level, defining the maximum number of batches processed sequencially without a delay within one reading/uploading cycle.
        ///
        /// `.medium` by default.
        public var batchProcessingLevel: BatchProcessingLevel

        /// Flag that determines if UIApplication methods [`beginBackgroundTask(expirationHandler:)`](https://developer.apple.com/documentation/uikit/uiapplication/1623031-beginbackgroundtaskwithexpiratio) and [`endBackgroundTask:`](https://developer.apple.com/documentation/uikit/uiapplication/1622970-endbackgroundtask)
        /// are utilized to perform background uploads. It may extend the amount of time the app is operating in background by 30 seconds.
        ///
        /// Tasks are normally stopped when there's nothing to upload or when encountering any upload blocker such us no internet connection or low battery.
        ///
        /// `false` by default.
        public var backgroundTasksEnabled: Bool

        /// Controls dashboard-managed remote configuration, which is enabled by default.
        ///
        /// When enabled, `Kubesense.initialize` loads the configuration cached by the previous launch (a small
        /// local file read, never a network call), features apply the settings it carries as they are enabled,
        /// and the SDK fetches a fresh document from `GET <collector>/rum/api/v1/sdk-config` in the background
        /// for the next launch, refreshing it periodically thereafter. Applications do not have to call anything.
        ///
        /// Disable it to keep the SDK strictly on the settings the application passes in code.
        ///
        /// `true` by default.
        public var remoteConfigurationEnabled: Bool

        /// How often the SDK re-fetches the remote configuration, for long running applications that rarely
        /// restart. Fetched values still apply at the next launch.
        ///
        /// Values below one minute are raised to one minute; a value of zero or less fetches once after
        /// initialization (and when the app returns to the foreground) and never on a timer.
        ///
        /// Six hours by default.
        public var remoteConfigurationRefreshPeriod: TimeInterval

        /// Creates a Kubesense SDK Configuration object.
        ///
        /// - Parameters:
        ///   - clientToken:                Either the RUM client token (which supports RUM, Logging and APM) or regular client token,
        ///                                 only for Logging and APM.
        ///
        ///   - env:                        The environment name which will be sent to Kubesense. This can be used
        ///                                 To filter events on different environments (e.g. "staging" or "production").
        ///
        ///   - site:                       Kubesense site, default value is `.prod`.
        ///
        ///   - service:                    The service name associated with data send to Kubesense.
        ///                                 Default value is set to application bundle identifier.
        ///
        ///   - version:                    The application version used for Unified Service Tagging.
        ///                                 If not provided, the SDK will use the version from the application's Info.plist
        ///                                 (`CFBundleShortVersionString` or `CFBundleVersion`).
        ///
        ///   - bundle:                     The bundle object that contains the current executable.
        ///
        ///   - batchSize:                  The preferred size of batched data uploaded to Kubesense servers.
        ///                                 This value impacts the size and number of requests performed by the SDK.
        ///                                 `.medium` by default.
        ///
        ///   - uploadFrequency:            The preferred frequency of uploading data to Kubesense servers.
        ///                                 This value impacts the frequency of performing network requests by the SDK.
        ///                                 `.average` by default.
        ///
        ///   - proxyConfiguration:         A proxy configuration attributes.
        ///                                 This can be used to a enable a custom proxy for uploading tracked data to Kubesense's intake.
        ///
        ///   - encryption:                 Data encryption to use for on-disk data persistency by providing an object
        ///                                 complying with `DataEncryption` protocol.
        ///
        ///   - serverDateProvider:         A custom NTP synchronization interface.
        ///                                 By default, the Kubesense SDK synchronizes with dedicated NTP pools provided by the
        ///                                 https://www.ntppool.org/ . Using different pools or setting a no-op `ServerDateProvider`
        ///                                 implementation will result in desynchronization of the SDK instance and the Kubesense servers.
        ///                                 This can lead to significant time shift in RUM sessions or distributed traces.
        ///   - backgroundTasksEnabled:     A flag that determines if `UIApplication` methods
        ///                                 `beginBackgroundTask(expirationHandler:)` and `endBackgroundTask:`
        ///                                 are used to perform background uploads.
        ///                                 It may extend the amount of time the app is operating in background by 30 seconds.
        ///                                 Tasks are normally stopped when there's nothing to upload or when encountering
        ///                                 any upload blocker such us no internet connection or low battery.
        ///                                 By default it's set to `false`.
        ///
        ///   - kubesenseRumEndpoint:       The host of a Kubesense RUM collector every feature uploads to, instead
        ///                                 of the one of `site`. Scheme and path are ignored; data is always sent
        ///                                 over https. Default is `nil`.
        ///
        ///   - remoteConfigurationEnabled: Whether dashboard-managed remote configuration is applied and fetched.
        ///                                 `true` by default.
        ///
        ///   - remoteConfigurationRefreshPeriod: How often the remote configuration is re-fetched. Six hours by default.
        public init(
            clientToken: String,
            env: String,
            site: KubesenseSite = .prod,
            service: String? = nil,
            version: String? = nil,
            bundle: Bundle = .main,
            batchSize: BatchSize = .medium,
            uploadFrequency: UploadFrequency = .average,
            proxyConfiguration: [AnyHashable: Any]? = nil,
            encryption: DataEncryption? = nil,
            serverDateProvider: ServerDateProvider? = nil,
            batchProcessingLevel: BatchProcessingLevel = .medium,
            backgroundTasksEnabled: Bool = false,
            kubesenseRumEndpoint: String? = nil,
            remoteConfigurationEnabled: Bool = true,
            remoteConfigurationRefreshPeriod: TimeInterval = Configuration.defaultRemoteConfigurationRefreshPeriod
        ) {
            self.clientToken = clientToken
            self.env = env
            self.site = site
            self.service = service
            self.version = version
            self.bundle = bundle
            self.batchSize = batchSize
            self.uploadFrequency = uploadFrequency
            self.proxyConfiguration = proxyConfiguration
            self.encryption = encryption
            self.serverDateProvider = serverDateProvider ?? KubesenseNTPDateProvider()
            self.batchProcessingLevel = batchProcessingLevel
            self.backgroundTasksEnabled = backgroundTasksEnabled
            self.kubesenseRumEndpoint = kubesenseRumEndpoint
            self.remoteConfigurationEnabled = remoteConfigurationEnabled
            self.remoteConfigurationRefreshPeriod = remoteConfigurationRefreshPeriod
        }

        /// The default interval between two fetches of the remote configuration: six hours.
        public static let defaultRemoteConfigurationRefreshPeriod: TimeInterval = 6 * 60 * 60

        /// The collector base URL resolved from `kubesenseRumEndpoint`, or `nil` when it does not hold a host.
        ///
        /// Mirrors the Android SDK's `useKubesenseRumEndpoint(host)`: surrounding whitespace, a leading
        /// `https://` or `http://` and anything from the first `/` are dropped, and the URL always uses https.
        internal var kubesenseRumEndpointURL: URL? {
            guard var host = kubesenseRumEndpoint?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return nil
            }
            for scheme in ["https://", "http://"] where host.lowercased().hasPrefix(scheme) {
                host = String(host.dropFirst(scheme.count))
            }
            if let slash = host.firstIndex(of: "/") {
                host = String(host[..<slash])
            }
            guard !host.isEmpty else {
                return nil
            }
            return URL(string: "https://\(host)")
        }

        // MARK: - Internal

        /// Obtains OS directory where SDK creates its root folder.
        /// All instances of the SDK use the same root folder, but each creates its own subdirectory.
        internal var systemDirectory: () throws -> Directory = { try Directory.cache() }

        /// Obtains OS directory where the SDK stores data that must survive `/Library/Caches` purges
        /// (e.g. remote configuration). Backed by `/Library/Application Support`.
        internal var persistentDirectory: () throws -> Directory = { try Directory.applicationSupport() }

        /// Default process information.
        internal var processInfo: ProcessInfo = .processInfo

        /// Sets additional configuration attributes.
        /// This can be used to tweak internal features of the SDK.
        internal var additionalConfiguration: [String: Any] = [:]

        /// Default date provider used by the SDK and all products.
        internal var dateProvider: DateProvider = SystemDateProvider()

        /// Creates `HTTPClient` with given proxy configuration attributes.
        internal var httpClientFactory: ([AnyHashable: Any]?) -> HTTPClient = { proxyConfiguration in
            URLSessionClient(proxyConfiguration: proxyConfiguration)
        }

        /// Provides notification centers used for subscribing to app lifecycle events and system notifications.
        internal var notificationCenterProvider: NotificationCenterProvider = .default

        /// The default app launch handler for tracking application startup time.
        internal var appLaunchHandler: AppLaunchHandling = AppLaunchHandler.shared

        /// The default application state provider for accessing [application state](https://developer.apple.com/documentation/uikit/uiapplication/state).
        internal var appStateProvider: AppStateProvider = DefaultAppStateProvider()
    }
}
