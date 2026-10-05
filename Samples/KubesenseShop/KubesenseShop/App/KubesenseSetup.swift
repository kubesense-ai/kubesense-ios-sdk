/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Kubesense addition to the fork of dd-sdk-ios, see docs/UPSTREAM_SYNC.md.
 */

import Foundation
import KubesenseCore
import KubesenseCrashReporting
import KubesenseFlags
import KubesenseLogs
import KubesenseRUM
import KubesenseSessionReplay
import KubesenseTrace
import OpenTelemetryApi

/// Starts the Kubesense features of the configured `SDKProfile`. Without credentials, or with the `.off`
/// profile, the app runs in preview mode: the shop works, nothing is uploaded.
enum KubesenseSetup {
    private(set) static var sdkEnabled = false
    private(set) static var logger: LoggerProtocol?

    static func start(with config: ShopConfig) {
        guard config.hasCredentials, config.sdkProfile != .off else { return }

        if config.sdkVerbose {
            Kubesense.verbosityLevel = .debug
        }
        Kubesense.initialize(
            with: Kubesense.Configuration(
                clientToken: config.clientToken,
                env: config.env,
                service: "kubesense-shop-ios",
                kubesenseRumEndpoint: config.rumEndpoint.isEmpty ? nil : config.rumEndpoint
            ),
            trackingConsent: .granted
        )

        let firstPartyHosts = Set([URL(string: config.sampleApiBaseURL)?.host, "kubesense.ai"].compactMap { $0 })

        RUM.enable(
            with: RUM.Configuration(
                applicationID: config.applicationID,
                sessionSampleRate: 100,
                uiKitViewsPredicate: DefaultUIKitRUMViewsPredicate(),
                uiKitActionsPredicate: DefaultUIKitRUMActionsPredicate(),
                swiftUIActionsPredicate: DefaultSwiftUIRUMActionsPredicate(isLegacyDetectionEnabled: true),
                urlSessionTracking: .init(firstPartyHostsTracing: .trace(hosts: firstPartyHosts, sampleRate: 100)),
                trackFrustrations: true,
                trackBackgroundEvents: true,
                longTaskThreshold: 0.1,
                appHangThreshold: 0.25,
                trackWatchdogTerminations: true,
                trackAnonymousUser: true,
                telemetrySampleRate: 100,
                collectAccessibility: true
            )
        )
        URLSessionInstrumentation.enableDurationBreakdown(with: .init(delegateClass: ShopURLSessionDelegate.self))
        RUMMonitor.shared().addAttribute(forKey: "variant", value: config.flavor)
        sdkEnabled = true
        guard config.sdkProfile != .rum else { return }

        let full = config.sdkProfile == .full
        if full {
            Logs.enable()
            Trace.enable(with: Trace.Configuration(networkInfoEnabled: true))
            OpenTelemetry.registerTracerProvider(tracerProvider: OTelTracerProvider())
            Flags.enable()
            CrashReporting.enable()
        }
        SessionReplay.enable(
            with: SessionReplay.Configuration(
                replaySampleRate: 100,
                textAndInputPrivacyLevel: .maskSensitiveInputs,
                imagePrivacyLevel: .maskNone,
                touchPrivacyLevel: .show,
                startRecordingImmediately: true,
                featureFlags: [.swiftui: true]
            )
        )

        guard full else { return }
        logger = Logger.create(
            with: Logger.Configuration(
                name: "kubesense-shop",
                networkInfoEnabled: true,
                consoleLogFormat: config.sdkVerbose ? .short : nil
            )
        )
    }
}
