/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import KubesenseInternal
import Foundation

/// An entry point to Kubesense RUM feature.
public enum RUM {
    /// Enables Kubesense RUM feature.
    ///
    /// After RUM is enabled, use `RUMMonitor.shared(in:)` to collect RUM events.
    ///
    /// - Parameters:
    ///   - configuration: Configuration of the feature.
    ///   - core: The instance of Kubesense SDK to enable RUM in (global instance by default).
    public static func enable(
        with configuration: RUM.Configuration,
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

    @MainActor
    internal static func enableOrThrow(
        with configuration: RUM.Configuration,
        in core: KubesenseCoreProtocol
    ) throws {
        guard !(core is NOPKubesenseCore) else {
            throw ProgrammerError(
                description: "Kubesense SDK must be initialized before calling `RUM.enable(with:)`."
            )
        }

        // A feature switched off from the dashboard is not registered at all.
        if core.isFeatureDisabledRemotely(featureKey: "rum", featureName: "RUM") {
            return
        }

        // Merge remote configuration on top of the in-code configuration. Remote values take
        // precedence for supported behavioral parameters; if no remote configuration is available,
        // the in-code configuration is used unchanged.
        var configuration = configuration
        configuration.apply(remoteConfiguration: core.remoteConfiguration)
        if let sessionSampleRate = core.remoteConfigDocument.sampleRate(RemoteConfigSection.rum, "sessionSampleRate") {
            configuration.sessionSampleRate = sessionSampleRate
        }
        if let collectAccessibility = core.remoteConfigDocument.bool(RemoteConfigSection.rum, "collectAccessibility") {
            configuration.collectAccessibility = collectAccessibility
        }

        // Register RUM feature:
        let rum = try RUMFeature(in: core, configuration: configuration)
        try core.register(feature: rum)

        if rum.timeseriesCollector != nil {
            core.telemetry.usage(event: .timeseries)
        }

        // If resource tracking is configured, register URLSessionHandler to enable network instrumentation:
        if let urlSessionConfig = configuration.urlSessionTracking {
            try RUM._internal.enableURLSessionTracking(with: urlSessionConfig, in: core)
        }

        if configuration.debugViews {
            consolePrint("⚠️ Overriding RUM debugging with KUBESENSE_DEBUG_RUM launch argument", .warn)
            rum.monitor.debug = true
        }

        // Do initial work:
        rum.monitor.notifySDKInit()
    }
}

extension RUM {
    /// Attributes that can be added to RUM calls that have special properies in Kubesense.
    public struct Attributes {
        /// Add a custom fingerprint to the RUM error.
        /// The value of this attribute must be a `String`.
        public static let errorFingerprint = "_kubesense.error.fingerprint"
    }
}
