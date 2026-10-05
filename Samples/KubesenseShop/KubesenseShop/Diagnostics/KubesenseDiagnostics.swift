/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Kubesense addition to the fork of dd-sdk-ios, see docs/UPSTREAM_SYNC.md.
 */

import Combine
import Foundation
import KubesenseCore
import KubesenseLogs
import KubesenseRUM
import KubesenseSessionReplay
import KubesenseTrace
import OpenTelemetryApi

enum DiagnosticGroup: String, CaseIterable, Identifiable {
    case rum = "Rum"
    case network = "Network"
    case logsTraces = "Logs traces"
    case replayContext = "Replay context"
    case reliability = "Reliability"

    var id: String { rawValue }
}

struct DiagnosticScenario: Identifiable {
    let id: String
    let title: String
    let description: String
    let group: DiagnosticGroup
    var destructive = false
}

private struct DiagnosticsFailure: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

/// One deterministic signal per scenario, mirroring the Android sample's observability lab.
enum KubesenseDiagnostics {
    static let scenarios: [DiagnosticScenario] = [
        .init(id: "action", title: "Manual action", description: "Send a richly attributed add-to-cart action.", group: .rum),
        .init(id: "timing", title: "Custom timing", description: "Attach catalog.ready to the active view.", group: .rum),
        .init(id: "operation", title: "Feature operation", description: "Run a successful checkout feature operation.", group: .rum),
        .init(id: "error", title: "Handled error", description: "Report a caught payment error.", group: .rum),
        .init(id: "resource", title: "Manual resource", description: "Create a successful manually tracked resource.", group: .network),
        .init(id: "network", title: "Instrumented request", description: "Run a real URLSession request through RUM resource tracking and tracing.", group: .network),
        .init(id: "logs", title: "Log burst", description: "Send debug, info, warning, and error logs through Logger.", group: .logsTraces),
        .init(id: "trace", title: "Manual trace", description: "Create Kubesense and OpenTelemetry spans.", group: .logsTraces),
        .init(id: "async", title: "Concurrency integrations", description: "Trace a Swift Task and report async and Combine failures.", group: .logsTraces),
        .init(id: "context", title: "User and account", description: "Set test user/account context and a feature flag evaluation.", group: .replayContext),
        .init(id: "replay_start", title: "Start replay", description: "Start Session Replay recording.", group: .replayContext),
        .init(id: "replay_stop", title: "Stop replay", description: "Stop Session Replay recording.", group: .replayContext),
        .init(id: "long_task", title: "Long task", description: "Block the main thread long enough to produce a long-task event.", group: .reliability),
        .init(id: "crash", title: "Swift crash", description: "Terminate the process with a fatal error.", group: .reliability, destructive: true),
        .init(id: "signal", title: "Native signal", description: "Terminate the process with SIGSEGV.", group: .reliability, destructive: true),
        .init(id: "hang", title: "App hang", description: "Block the main thread for 20 seconds.", group: .reliability, destructive: true),
    ]

    private static var cancellables = Set<AnyCancellable>()

    @MainActor
    static func run(_ id: String) async -> String {
        guard KubesenseSetup.sdkEnabled else {
            return "SDK disabled: add token and RUM application ID in Config/local.json"
        }
        let rum = RUMMonitor.shared()
        switch id {
        case "action":
            rum.addAction(type: .custom, name: "diagnostics.add_to_cart", attributes: ["sku": "terra-01", "quantity": 1])
            return "Manual action sent"
        case "timing":
            rum.addTiming(name: "catalog.ready")
            rum.addViewAttributes(["catalog.origin": "diagnostics"])
            return "Timing and view attributes sent"
        case "operation":
            let key = UUID().uuidString
            rum.startOperation(name: "checkout", operationKey: key, attributes: ["items": 2])
            try? await Task.sleep(nanoseconds: 350_000_000)
            rum.succeedOperation(name: "checkout", operationKey: key, attributes: ["result": "authorized"])
            return "Checkout operation completed"
        case "error":
            rum.addError(
                error: DiagnosticsFailure("Payment provider rejected the test transaction"),
                source: .source,
                attributes: ["payment.provider": "sample"]
            )
            return "Handled error reported"
        case "resource":
            let key = UUID().uuidString
            rum.startResource(resourceKey: key, httpMethod: .get, urlString: "/products/featured")
            try? await Task.sleep(nanoseconds: 200_000_000)
            rum.stopResource(resourceKey: key, statusCode: 200, kind: .native, size: 2048, attributes: ["cache": "miss"])
            return "Manual resource completed"
        case "network":
            do {
                let session = URLSession(configuration: .default, delegate: ShopURLSessionDelegate(), delegateQueue: nil)
                let (_, response) = try await session.data(from: URL(string: "https://www.kubesense.ai/")!)
                return "Request completed with HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)"
            } catch {
                return "Request failed as expected in some environments: \(error.localizedDescription)"
            }
        case "logs":
            let logger = Logger.create(with: Logger.Configuration(name: "diagnostics", consoleLogFormat: .short))
            logger.debug("Catalog diagnostics started", attributes: ["source": "diagnostics"])
            logger.info("Inventory refreshed", attributes: ["items": 104])
            logger.warn("Inventory is low", attributes: ["sku": "orbit-03"])
            logger.error("Synthetic checkout failure", error: DiagnosticsFailure("test-only"))
            KubesenseSetup.logger?.info("Shop logger integration is active")
            return "Log burst sent"
        case "trace":
            let span = Tracer.shared().startSpan(operationName: "diagnostics.checkout")
            span.setTag(key: "cart.items", value: 2)
            span.finish()
            OpenTelemetry.instance.tracerProvider
                .get(instrumentationName: "kubesense-shop", instrumentationVersion: nil)
                .spanBuilder(spanName: "diagnostics.otel")
                .startSpan()
                .end()
            return "Kubesense and OpenTelemetry spans sent"
        case "async":
            let span = Tracer.shared().startSpan(operationName: "diagnostics.task").setActive()
            try? await Task.sleep(nanoseconds: 80_000_000)
            span.finish()
            do {
                try await failingAsyncWork()
            } catch {
                rum.addError(error: error, source: .source, attributes: ["integration": "swift-concurrency"])
            }
            Fail<Int, DiagnosticsFailure>(error: DiagnosticsFailure("Synthetic Combine failure"))
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            RUMMonitor.shared().addError(error: error, source: .source, attributes: ["integration": "combine"])
                        }
                    },
                    receiveValue: { _ in }
                )
                .store(in: &cancellables)
            return "Traced Task, async and Combine errors completed"
        case "context":
            Kubesense.setUserInfo(id: "sample-admin-42", name: "Kubesense Admin", email: "admin@kubesense.ai", extraInfo: ["tier": "explorer"])
            Kubesense.setAccountInfo(id: "sample-store", name: "Kubesense Shop", extraInfo: ["plan": "demo"])
            rum.addFeatureFlagEvaluation(name: "new_checkout", value: true)
            return "User, account, and flag context updated"
        case "replay_start":
            SessionReplay.startRecording()
            return "Session Replay started"
        case "replay_stop":
            SessionReplay.stopRecording()
            return "Session Replay stopped"
        case "long_task":
            Thread.sleep(forTimeInterval: 0.35)
            return "350 ms main-thread task completed"
        case "crash":
            fatalError("Intentional Kubesense Shop Swift crash")
        case "signal":
            raise(SIGSEGV)
            return "Signal raised"
        case "hang":
            Thread.sleep(forTimeInterval: 20)
            return "Main thread blocked for 20 seconds"
        default:
            return "Unknown scenario"
        }
    }

    private static func failingAsyncWork() async throws {
        try await Task.sleep(nanoseconds: 50_000_000)
        throw DiagnosticsFailure("Synthetic async failure")
    }
}
