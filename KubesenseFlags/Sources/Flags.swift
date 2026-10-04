/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import Foundation
import KubesenseInternal

/// Kubesense Feature Flags SDK.
///
/// The Flags SDK enables feature flag evaluation and management in your iOS application,
/// integrating with Kubesense's feature flag service for dynamic configuration and experimentation.
///
/// To use feature flags in your application:
///
/// 1. Enable the Flags feature after initializing the Kubesense SDK
/// 2. Create a `FlagsClient` to evaluate flags
/// 3. Set the evaluation context with user/session information
/// 4. Evaluate flags throughout your application
public enum Flags {
    /// Configuration options for the Kubesense Flags feature.
    ///
    /// Use this type to customize the behavior of feature flag evaluation, including exposure tracking
    /// and error handling modes.
    public struct Configuration {
        internal static let defaultInitializationTimeout: TimeInterval? = 5

        /// Controls error handling behavior for `FlagsClient` API misuse.
        ///
        /// This setting determines how the SDK responds to incorrect usage, such as:
        /// - Creating a `FlagsClient` that already exists
        /// - Retrieving a `FlagsClient` that was never created
        /// - Creating a `FlagsClient` before calling `Flags.enable()`
        ///
        /// Error handling is selected based on the build configuration and this setting:
        /// - Release builds use safe defaults with SDK level-based logging
        /// - Debug builds with `gracefulModeEnabled = true` log warnings to console instead of crashing
        /// - Debug builds with `gracefulModeEnabled = false` crashes with fatal errors for fail-fast development
        ///
        /// Recommended usage:
        /// - Set to `false` in development, test, and QA builds for immediate error detection
        /// - Set to `true` (default) in dogfooding and staging environments for visible warnings without crashes
        /// - Production builds always handle errors gracefully regardless of this setting
        ///
        /// Default: `true`.
        public var gracefulModeEnabled: Bool

        /// Not part of the Kubesense API: flag assignments, exposures and evaluations go to the core-level
        /// collector endpoint (`Kubesense.Configuration.kubesenseRumEndpoint`, or the site's). Kept internal as
        /// a test hook.
        internal var customFlagsEndpoint: URL? = nil

        /// Additional HTTP headers to attach to the flag assignments request (`POST /precompute-assignments`
        /// on the collector).
        ///
        /// Useful for authentication or routing through a proxy in front of the collector.
        ///
        /// Default: `nil`.
        public var customFlagsHeaders: [String: String]?

        /// The maximum time to wait for the first evaluation context to become ready.
        ///
        /// This timeout covers the complete initialization operation. It includes loading cached data,
        /// fetching assignments, reading the response body, decoding JSON, and publishing the ready state.
        /// It does not change the HTTP client's timeout. The assignment operation continues after this timeout
        /// and can update the client to ``FlagsClientState/ready`` when it completes.
        ///
        /// The timeout applies to the first ``FlagsClientProtocol/setEvaluationContext(_:completion:)`` call only.
        /// That call consumes the timeout even if the operation fails or never starts. Later calls have no timer.
        ///
        /// The value is in seconds. A positive finite value enables the timeout. `nil`, zero, negative, and
        /// non-finite values disable it.
        ///
        /// Default: `5` seconds.
        public var initializationTimeout: TimeInterval?

        /// Not part of the Kubesense API: flag assignments, exposures and evaluations go to the core-level
        /// collector endpoint (`Kubesense.Configuration.kubesenseRumEndpoint`, or the site's). Kept internal as
        /// a test hook.
        internal var customExposureEndpoint: URL? = nil

        /// Enables exposure logging via the dedicated exposures intake endpoint.
        ///
        /// When enabled, flag evaluation events are sent to the exposures endpoint for analytics and monitoring.
        ///
        /// Default: `true`.
        public var trackExposures: Bool

        /// Not part of the Kubesense API: flag assignments, exposures and evaluations go to the core-level
        /// collector endpoint (`Kubesense.Configuration.kubesenseRumEndpoint`, or the site's). Kept internal as
        /// a test hook.
        internal var customEvaluationEndpoint: URL? = nil

        /// Enables evaluation logging via the dedicated evaluations intake endpoint.
        ///
        /// When enabled, all flag evaluations are aggregated and sent to the evaluations endpoint for operational monitoring.
        ///
        /// Default: `true`.
        public var trackEvaluations: Bool

        /// The interval at which aggregated evaluation data is flushed to the server.
        ///
        /// Values are clamped to a minimum of 1 second and maximum of 60 seconds.
        ///
        /// Default: `10.0` seconds.
        public var evaluationFlushInterval: TimeInterval

        /// Enables the RUM integration.
        ///
        /// When enabled, flag evaluation events are sent to RUM for correlation with user sessions.
        ///
        /// Default: `true`.
        public var rumIntegrationEnabled: Bool

        /// Creates a configuration for the Kubesense Flags feature.
        ///
        /// - Parameters:
        ///   - gracefulModeEnabled: Controls error handling behavior for API misuse. Default: `true`.
        ///   - customFlagsHeaders: Additional HTTP headers for the flag assignments request. Default: `nil`.
        ///   - initializationTimeout: Maximum time to wait for the first evaluation context. Default: `5` seconds.
        ///   - trackExposures: Enables exposure logging to the exposures intake endpoint. Default: `true`.
        ///   - trackEvaluations: Enables evaluation logging to the evaluations intake endpoint. Default: `true`.
        ///   - evaluationFlushInterval: The interval for flushing aggregated evaluation data. Default: `10.0` seconds.
        ///   - rumIntegrationEnabled: Enables the RUM integration for flag evaluations. Default: `true`.
        public init(
            gracefulModeEnabled: Bool = true,
            customFlagsHeaders: [String: String]? = nil,
            initializationTimeout: TimeInterval? = 5,
            trackExposures: Bool = true,
            trackEvaluations: Bool = true,
            evaluationFlushInterval: TimeInterval = 10.0,
            rumIntegrationEnabled: Bool = true
        ) {
            self.gracefulModeEnabled = gracefulModeEnabled
            self.customFlagsHeaders = customFlagsHeaders
            self.initializationTimeout = initializationTimeout
            self.trackExposures = trackExposures
            self.trackEvaluations = trackEvaluations
            self.evaluationFlushInterval = evaluationFlushInterval
            self.rumIntegrationEnabled = rumIntegrationEnabled
        }
    }

    /// Enables the Kubesense Flags feature in your application.
    ///
    /// Call this method after initializing the Kubesense SDK to enable feature flag evaluation.
    /// This method must be called before creating any `FlagsClient` instances.
    ///
    /// ```swift
    /// import KubesenseCore
    /// import KubesenseFlags
    ///
    /// // Initialize Kubesense SDK
    /// Kubesense.initialize(
    ///     with: Kubesense.Configuration(
    ///         clientToken: "<client_token>",
    ///         env: "<environment>"
    ///     ),
    ///     trackingConsent: .granted
    /// )
    ///
    /// // Enable Flags feature
    /// Flags.enable()
    /// ```
    ///
    /// - Parameters:
    ///   - configuration: Configuration options for the Flags feature. Defaults to standard configuration.
    ///   - core: The Kubesense SDK core instance. Defaults to the global shared instance.
    public static func enable(
        with configuration: Flags.Configuration = .init(),
        in core: KubesenseCoreProtocol = CoreRegistry.default
    ) {
        do {
            // To ensure the correct registration order between Core and Features,
            // the entire initialization flow is synchronized on the main thread.
            try runOnMainThreadSync {
                try enableOrThrow(with: configuration, in: core)
            }
        } catch let error {
            consolePrint("\(error)", .error)
        }
    }

    internal static func enableOrThrow(
        with configuration: Flags.Configuration,
        in core: KubesenseCoreProtocol
    ) throws {
        guard !(core is NOPKubesenseCore) else {
            throw ProgrammerError(
                description: "Kubesense SDK must be initialized before calling `Flags.enable(with:)`."
            )
        }

        // A feature switched off from the dashboard is not registered at all.
        if core.isFeatureDisabledRemotely(featureKey: "flags", featureName: "Flags") {
            return
        }

        // Dashboard-managed settings override what the application configured in code.
        var configuration = configuration
        let document = core.remoteConfigDocument
        if let trackExposures = document.bool(RemoteConfigSection.flags, "trackExposures") {
            configuration.trackExposures = trackExposures
        }
        if let rumIntegrationEnabled = document.bool(RemoteConfigSection.flags, "rumIntegrationEnabled") {
            configuration.rumIntegrationEnabled = rumIntegrationEnabled
        }

        if configuration.trackEvaluations {
            let evaluationFeature = FlagsEvaluationFeature(
                customIntakeURL: configuration.customEvaluationEndpoint,
                telemetry: core.telemetry
            )
            try core.register(feature: evaluationFeature)
        }

        let featureScope = core.scope(for: FlagsFeature.self) // safe to obtain scope before feature registration; scope is lazily evaluated
        let feature = FlagsFeature(
            configuration: configuration,
            featureScope: featureScope,
            core: core
        )
        try core.register(feature: feature)
    }
}
