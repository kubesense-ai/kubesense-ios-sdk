/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import Foundation
import KubesenseInternal

#if !os(watchOS)

extension Profiling {
    /// Configuration options for the profiling feature.
    public struct Configuration: Sendable {
        /// Not part of the Kubesense API: every feature uploads to the core-level collector endpoint
        /// (`Kubesense.Configuration.kubesenseRumEndpoint`, or the site's). Kept internal as a test hook, to capture
        /// uploads in unit and integration tests.
        internal var customEndpoint: URL? = nil

        /// The sampling rate for App Launch Profiling.
        ///
        /// It must be a number between 0.0 and 100.0, where 0 means no profiles will be collected.
        ///
        /// Default: `5.0`.
        public var applicationLaunchSampleRate: SampleRate

        /// The sampling rate for continuous Profiling.
        ///
        /// It must be a number between 0.0 and 100.0, where 0 means no profiles will be collected.
        ///
        /// Default: `5.0`.
        public var continuousSampleRate: SampleRate

        // MARK: - Internal

        internal var debugSDK: Bool = ProcessInfo.processInfo.arguments.contains(LaunchArguments.Debug)
        internal var minProfileDuration: TimeInterval = KubesenseProfiler.Constants.minProfileDuration

        /// Creates the Profiling configuration.
        /// - Parameters:
        ///   - applicationLaunchSampleRate: The sampling rate for the application launch profiling.
        public init(
            applicationLaunchSampleRate: SampleRate = 5,
            continuousSampleRate: SampleRate = 5
        ) {
            self.applicationLaunchSampleRate = applicationLaunchSampleRate
            self.continuousSampleRate = continuousSampleRate
        }

        /// Merges the remote configuration on top of this in-code configuration.
        ///
        /// Remote values take precedence for the supported behavioral parameters; any parameter the
        /// remote configuration omits keeps its in-code value. Passing `nil` (no remote configuration was
        /// fetched) therefore leaves the configuration entirely unchanged.
        ///
        /// The merge happens once, at `Profiling.enable(with:)` time; live updates after initialization
        /// are out of scope.
        ///
        /// - Parameter remoteConfiguration: The remote configuration to merge, or `nil` when none is
        ///   available (leaving this configuration unchanged).
        mutating func apply(remoteConfiguration: RemoteConfiguration?) {
            if let applicationLaunchSampleRate = remoteConfiguration?.profiling?.applicationLaunchSampleRate {
                self.applicationLaunchSampleRate = SampleRate(applicationLaunchSampleRate)
            }

            if let continuousSampleRate = remoteConfiguration?.profiling?.continuousSampleRate {
                self.continuousSampleRate = SampleRate(continuousSampleRate)
            }
        }
    }
}

#endif
