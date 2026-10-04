/*
* Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
* This product includes software developed at Datadog (https://www.datadoghq.com/).
* Copyright 2019-Present Datadog, Inc.
*/

import Foundation
import KubesenseInternal
import OpenTelemetryApi

/// The Kubesense implementation of OpenTelemetry `TracerProvider`.
/// It takes the Kubesense SDK instance as a dependency and returns the tracer from it.
///
/// Usage:
///
/// ```swift
/// import OpenTelemetryApi
/// import KubesenseTrace
///
/// // Register the tracer provider
/// OpenTelemetry.registerTracerProvider(
///     tracerProvider: OTelTracerProvider()
/// )
///
/// // Get the tracer
/// let tracer = OpenTelemetry
///     .instance
///     .tracerProvider
///     .get(instrumentationName: "", instrumentationVersion: nil)
///
/// // Start a span
/// let span = tracer
///     .spanBuilder(spanName: "OperationName")
///     .startSpan()
/// ```
public class OTelTracerProvider: OpenTelemetryApi.TracerProvider {
    private weak var core: KubesenseCoreProtocol?

    /// Creates a tracer provider with the given Kubesense SDK instance.
    /// - Parameter core: the instance of Kubesense SDK the Trace feature was enabled in (global instance by default)
    public init(in core: KubesenseCoreProtocol = CoreRegistry.default) {
        self.core = core
    }

    /// Returns a tracer with the given instrumentation name and version.
    /// - Parameters:
    ///   - instrumentationName: the name of the instrumentation library, not the name of the instrumented library
    ///     Note: This is ignored, as the Kubesense SDK works on concept of core.
    ///   - instrumentationVersion:  The version of the instrumentation library (e.g., "semver:1.0.0"). Optional
    ///     Note: This is ignored, as the Kubesense SDK works on concept of core.
    ///   - schemaUrl: The schema url. Optional
    ///     Note: This is ignored in Kubesense SDK.
    ///   - attributes: Attributes to be associated with spans created by this tracer. Optional.
    ///     Note: This is ignored by the Kubesense SDK. To configure default tags for the tracer, use `Trace.Configuration`
    ///     passed to `Trace.enable()`.
    public func get(
        instrumentationName: String,
        instrumentationVersion: String?,
        schemaUrl: String?,
        attributes: [String: OpenTelemetryApi.AttributeValue]?
    ) -> any OpenTelemetryApi.Tracer {
        return get(instrumentationName: instrumentationName, instrumentationVersion: instrumentationVersion)
    }

    /// Returns a tracer with the given instrumentation name and version.
    /// - Parameters:
    ///   - instrumentationName: the name of the instrumentation library, not the name of the instrumented library
    ///     Note: This is ignored, as the Kubesense SDK works on concept of core.
    ///   - instrumentationVersion:  The version of the instrumentation library (e.g., "semver:1.0.0"). Optional
    ///     Note: This is ignored, as the Kubesense SDK works on concept of core.
    public func get(instrumentationName: String, instrumentationVersion: String?) -> OpenTelemetryApi.Tracer {
        do {
            guard !(core is NOPKubesenseCore) else {
                throw ProgrammerError(
                    description: "Kubesense SDK must be initialized and Trace feature must be enabled before calling `OTelTracerProvider.get(instrumentationName:instrumentationVersion:)`."
                )
            }
            guard let feature = core?.get(feature: TraceFeature.self) else {
                throw ProgrammerError(
                    description: "Trace feature must be enabled before calling `OTelTracerProvider.get(instrumentationName:instrumentationVersion:)`."
                )
            }

            // Send tracer API usage to telemetry
            core?.telemetry.configuration(tracerAPI: "OpenTelemetry", tracerAPIVersion: OpenTelemetry.version)

            return feature.tracer
        } catch {
            consolePrint("\(error)", .error)
            return KubesenseNoopTracer()
        }
    }
}
