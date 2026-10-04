/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

#if os(iOS)
import Foundation
import KubesenseInternal

/// An entry point to Kubesense Session Replay feature.
public enum SessionReplay {
    /// Enables Kubesense Session Replay feature.
    ///
    /// Recording will start automatically after enabling Session Replay.
    ///
    /// Note: Session Replay requires the RUM feature to be enabled.
    ///
    /// - Parameters:
    ///   - configuration: Configuration of the feature.
    ///   - core: The instance of Kubesense SDK to enable Session Replay in (global instance by default).
    public static func enable(
        with configuration: SessionReplay.Configuration,
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

    /// Starts the recording manually.
    /// - Parameters:
    ///   - core: The instance of Kubesense SDK to start Session Replay in (global instance by default).
    public static func startRecording(
        in core: KubesenseCoreProtocol = CoreRegistry.default
    ) {
        do {
            try startRecording(core: core)
        } catch let error {
            consolePrint("\(error)", .error)
        }
    }

    /// Stops the recording manually.
    /// - Parameters:
    ///   - core: The instance of Kubesense SDK to start Session Replay in (global instance by default).
    public static func stopRecording(
        in core: KubesenseCoreProtocol = CoreRegistry.default
    ) {
        do {
            try stopRecording(core: core)
        } catch let error {
            consolePrint("\(error)", .error)
        }
    }

    // MARK: Internal

    internal static let maxObjectSize = 10.MB.asUInt32()

    internal static func enableOrThrow(
        with configuration: SessionReplay.Configuration,
        in core: KubesenseCoreProtocol
    ) throws {
        guard !(core is NOPKubesenseCore) else {
            throw ProgrammerError(
                description: "Kubesense SDK must be initialized before calling `SessionReplay.enable(with:)`."
            )
        }

        guard !CoreRegistry.isFeatureEnabled(feature: SessionReplayFeature.self) else {
            core.telemetry.debug("Session Replay has already been enabled")
            throw ProgrammerError(
                description: "Session Replay is already enabled and does not support multiple instances. The existing instance will continue to be used."
            )
        }

        // Merge remote configuration on top of the in-code configuration. Remote values take
        // precedence for supported behavioral parameters; if no remote configuration is available,
        // the in-code configuration is used unchanged. Applied before the sample-rate guard so a
        // remote `sampleRate` can enable or disable recording.
        if core.isFeatureDisabledRemotely(featureKey: "sessionReplay", featureName: "Session Replay") {
            return
        }

        var configuration = configuration
        configuration.apply(remoteConfiguration: core.remoteConfiguration)
        if let startRecordingImmediately = core.remoteConfigDocument.bool(RemoteConfigSection.sessionReplay, "startRecordingImmediately") {
            configuration.startRecordingImmediately = startRecordingImmediately
        }

        guard configuration.replaySampleRate > 0 else {
            return
        }
        let resources = ResourcesFeature(core: core, configuration: configuration)
        try core.register(feature: resources)

        let sessionReplay = try SessionReplayFeature(core: core, configuration: configuration)
        try core.register(feature: sessionReplay)
        core.set(
            context: SessionReplayCoreContext.Configuration(
                sampleRate: configuration.replaySampleRate,
                startRecordingManually: !configuration.startRecordingImmediately,
                experimentalFeatures: configuration.featureFlags.stringValues
            )
        )

        core.telemetry.configuration(
            defaultPrivacyLevel: nil,
            textAndInputPrivacyLevel: configuration.textAndInputPrivacyLevel.rawValue,
            imagePrivacyLevel: configuration.imagePrivacyLevel.rawValue,
            touchPrivacyLevel: configuration.touchPrivacyLevel.rawValue,
            sessionReplaySampleRate: Int64.kubesenseWithNoOverflow(configuration.replaySampleRate),
            startRecordingImmediately: configuration.startRecordingImmediately
        )
    }

    internal static func startRecording(core: KubesenseCoreProtocol) throws {
        guard let sr = core.get(feature: SessionReplayFeature.self) else {
            throw ProgrammerError(
                description: "Session Replay must be initialized before calling `SessionReplay.startRecording()`."
            )
        }

        sr.startRecording()
    }

    internal static func stopRecording(core: KubesenseCoreProtocol) throws {
        let sr = core.get(feature: SessionReplayFeature.self)
        sr?.stopRecording()
    }
}
#endif
