/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import Foundation
import KubesenseInternal
import OpenTelemetryApi

internal struct KubesenseNoopGlobals {
    static let tracer = KubesenseNoopTracer()
    static let span = KubesenseNoopSpan()
    static let context = KubesenseNoopSpanContext()
}

internal final class KubesenseNoopTracer: OTTracer, OpenTelemetryApi.Tracer, Sendable {
    var activeSpan: OTSpan? { nil }

    private func warn() {
        KS.logger.warn(
            """
            The `KubesenseTracer.shared()` was called but `KubesenseTracer` is not initialised. Configure the `KubesenseTracer` before invoking the feature:
                KubesenseTracer.initialize()
            See https://docs.kubesense.ai/tracing/setup_overview/setup/ios
            """
        )
    }

    func extract(reader: OTFormatReader) -> OTSpanContext? {
        warn()
        return KubesenseNoopGlobals.context
    }

    func inject(spanContext: OTSpanContext, writer: OTFormatWriter) {
        warn()
    }

    func startSpan(operationName: String, references: [OTReference]?, tags: [String: OTTagValue]?, startTime: Date?) -> OTSpan {
        warn()
        return KubesenseNoopGlobals.span
    }

    func startRootSpan(operationName: String, tags: [String: OTTagValue]?, startTime: Date?) -> OTSpan {
        warn()
        return KubesenseNoopGlobals.span
    }

    func startRootSpan(operationName: String, tags: [String: any OTTagValue]?, startTime: Date?, customSampleRate: SampleRate?) -> any OTSpan {
        warn()
        return KubesenseNoopGlobals.span
    }

    // MARK: - Open Telemetry

    func spanBuilder(spanName: String) -> OpenTelemetryApi.SpanBuilder {
        warn()
        return NOPOTelSpanBuilder()
    }
}

internal struct KubesenseNoopSpan: OTSpan {
    var context: OTSpanContext { KubesenseNoopGlobals.context }
    func tracer() -> OTTracer { KubesenseNoopGlobals.tracer }
    func setOperationName(_ operationName: String) {}
    func finish(at time: Date) {}
    func log(fields: [String: Encodable & Sendable], timestamp: Date) {}
    func baggageItem(withKey key: String) -> String? { nil }
    func setBaggageItem(key: String, value: String) {}
    func setTag(key: String, value: OTTagValue) {}
    @discardableResult
    func setActive() -> OTSpan { self }
}

internal struct KubesenseNoopSpanContext: OTSpanContext {
    func forEachBaggageItem(callback: (String, String) -> Bool) {}
}
