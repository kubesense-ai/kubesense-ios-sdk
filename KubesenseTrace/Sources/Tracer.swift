/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import Foundation
import KubesenseInternal
import OpenTelemetryApi

/// Kubesense - specific span tags to be used with `Tracer.shared().startSpan(operationName:references:tags:startTime:)`
/// and `span.setTag(key:value:)`.
public enum SpanTags {
    /// A Kubesense-specific span tag, which sets the value appearing in the "RESOURCE" column
    /// in traces explorer on [app.kubesense.ai](https://app.kubesense.ai/)
    /// Can be used to customize the resource names grouped under the same operation name.
    ///
    /// Expects `String` value set for a tag.
    public static let resource = "resource.name"
    /// A Kubesense-specific span tag, which sets the operation name
    public static let operation = "operation.name"
    /// A Kubesense-specific span tag, which sets the value appearing in the "SERVICE" column
    public static let service = "service.name"
    /// Internal tag. `Integer` value. Measures elapsed time at app's foreground state in nanoseconds.
    /// (duration - foregroundDuration) gives you the elapsed time while the app wasn't active (probably at background)
    internal static let foregroundDuration = "foreground_duration"
    /// Internal tag. `Bool` value.
    /// `true` if span was started or ended while the app was not active, `false` otherwise.
    internal static let isBackground = "is_background"
    /// Internal tag used to encode error type received from the user through `OTLogFields`.
    internal static let errorType = "error.type"
    /// Internal tag used to encode error message received from the user through `OTLogFields`.
    internal static let errorMessage = "error.msg"
    /// Internal tag used to encode error stack received from the user through `OTLogFields`.
    internal static let errorStack = "error.stack"

    /// Internal tag used to encode the RUM application ID, linking the span to the current RUM session.
    internal static let rumApplicationID = "_kubesense.application.id"
    /// Internal tag used to encode the RUM session ID, linking the span to the current RUM session.
    internal static let rumSessionID = "_kubesense.session.id"
    /// Internal tag used to encode the RUM view ID, linking the span to the current RUM session.
    internal static let rumViewID = "_kubesense.view.id"
    /// Internal tag used to encode the RUM action ID, linking the span to the current RUM session.
    internal static let rumActionID = "_kubesense.action.id"
    /// Tag used to encode the RUM view name, so spans can be searched and grouped by view in APM.
    ///
    /// Unlike the RUM IDs above, this tag is deliberately not `_kubesense.`-prefixed: it is a user-facing
    /// facet (`@view.name`) and mirrors the attribute Browser RUM sets. Do not add the prefix.
    internal static let rumViewName = "view.name"
    /// Internal tag used to encode the span kind. This can be either "client" or "server" for RPC spans,
    /// and "producer" or "consumer" for messaging spans.
    internal static let kind = "span.kind"
    /// Tag used to mark a span as manually dropped.
    public static let manualDrop = "manual.drop"
    /// Tag used to mark a span as manually kept.
    public static let manualKeep = "manual.keep"
}

/// A class for manual interaction with the Trace feature. It records spans that are sent to Kubesense APM.
///
/// There can be only one active Tracer for certain instance of Kubesense SDK. It gets enabled along with
/// the call to `Trace.enable(with:in:)`:
///
///     import KubesenseTrace
///
///     // Enable Trace feature:
///     Trace.enable(with: configuration)
///
///     // Use Tracer:
///     Tracer.shared().startSpan(...)
///
public class Tracer {
    /// Obtains the Tracer for manual tracing instrumentation.
    ///
    /// It requires `Trace.enable(with:in:)` to be called first - otherwise it will return no-op implementation.
    /// - Parameter core: the instance of Kubesense SDK the Trace feature was enabled in (global instance by default)
    /// - Returns: the Tracer that conforms to Open Tracing API (`OTTracer`)
    public static func shared(in core: KubesenseCoreProtocol = CoreRegistry.default) -> OTTracer {
        do {
            guard !(core is NOPKubesenseCore) else {
                throw ProgrammerError(
                    description: "Kubesense SDK must be initialized and RUM feature must be enabled before calling `Tracer.shared(in:)`."
                )
            }
            guard let feature = core.get(feature: TraceFeature.self) else {
                throw ProgrammerError(
                    description: "Trace feature must be enabled before calling `Tracer.shared(in:)`."
                )
            }

            // Send tracer API usage to telemetry
            core.telemetry.configuration(tracerAPI: "OpenTracing")

            return feature.tracer
        } catch {
            consolePrint("\(error)", .error)
            return KubesenseNoopTracer()
        }
    }
}
