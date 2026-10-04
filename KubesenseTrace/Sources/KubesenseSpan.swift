/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import Foundation
import KubesenseInternal

internal final class KubesenseSpan: OTSpan, @unchecked Sendable {
    /// The `Tracer` which created this span.
    private let kubesenseTracer: KubesenseTracer
    /// Span context.
    internal let kubesenseContext: KubesenseSpanContext
    /// Span creation date
    internal let startTime: Date
    /// Writes span logs to Logging Feature. `nil` if Logging feature is disabled.
    private let loggingIntegration: TracingWithLoggingIntegration

    /// Span operation name.
    @ReadWriteLock
    private var operationName: String
    /// Span tags.
    @ReadWriteLock
    private var tags: [String: OTTagValue]
    /// Span log fields.
    @ReadWriteLock
    private var logFields: [[String: Encodable & Sendable]]
    /// If this span has completed.
    @ReadWriteLock
    private var isFinished: Bool
    @ReadWriteLock
    private var activityReference: ActivityReference?
    /// Builds span events.
    private let eventBuilder: SpanEventBuilder
    /// Writes span events to core.
    private let eventWriter: SpanWriteContext

    init(
        tracer: KubesenseTracer,
        context: KubesenseSpanContext,
        operationName: String,
        startTime: Date,
        tags: [String: OTTagValue],
        eventBuilder: SpanEventBuilder,
        eventWriter: SpanWriteContext
    ) {
        self.kubesenseTracer = tracer
        self.kubesenseContext = context
        self.startTime = startTime
        self.loggingIntegration = tracer.loggingIntegration
        self.operationName = operationName
        self.tags = tags
        self.logFields = []
        self.isFinished = false
        self.eventBuilder = eventBuilder
        self.eventWriter = eventWriter
    }

    // MARK: - Open Tracing interface

    var context: OTSpanContext {
        return kubesenseContext
    }

    func tracer() -> OTTracer {
        return kubesenseTracer
    }

    func setOperationName(_ operationName: String) {
        if warnIfFinished("setOperationName(_:)") {
            return
        }
        self.operationName = operationName
    }

    func setTag(key: String, value: OTTagValue) {
        if warnIfFinished("setTag(key:value:)") {
            return
        }

        if kubesenseContext.span(self, willSetTagWithKey: key, value: value) {
            _tags.mutate { $0[key] = value }
        }
    }

    func setBaggageItem(key: String, value: String) {
        if warnIfFinished("setBaggageItem(key:value:)") {
            return
        }
        kubesenseContext.baggageItems.set(key: key, value: value)
    }

    func baggageItem(withKey key: String) -> String? {
        if warnIfFinished("baggageItem(withKey:)") {
            return nil
        }
        return kubesenseContext.baggageItems.get(key: key)
    }

    @discardableResult
    func setActive() -> OTSpan {
        activityReference = ActivityReference()
        if let activityReference = activityReference {
            kubesenseTracer.addSpan(span: self, activityReference: activityReference)
        }
        return self
    }

    func log(fields: [String: Encodable & Sendable], timestamp: Date) {
        log(message: nil, fields: fields, timestamp: timestamp)
    }

    func log(message: String?, fields: [String: Encodable & Sendable], timestamp: Date) {
        if warnIfFinished("log(fields:timestamp:)") {
            return
        }
        logFields.append(fields)
        sendSpanLogs(message: message, fields: fields, date: timestamp)
    }

    func finish(at time: Date) {
        var shouldRun = true
        _isFinished.mutate {
            if warnIfFinished("finish(at:)", isFinished: $0) {
                shouldRun = false
                return
            }
            $0 = true
        }
        if !shouldRun {
            return
        }

        if let activity = activityReference {
            kubesenseTracer.removeSpan(span: self)
            activity.leave()
        }
        if self.kubesenseContext.samplingDecision.samplingPriority.isKept {
            sendSpan(finishTime: time)
        }
    }

    // MARK: - Writing SpanEvent

    /// Sends span event for given `KubesenseSpan`.
    private func sendSpan(finishTime: Date) {
        eventWriter.spanWriteContext { context, writer in
            let event = self.eventBuilder.createSpanEvent(
                context: context,
                traceID: self.kubesenseContext.traceID,
                spanID: self.kubesenseContext.spanID,
                parentSpanID: self.kubesenseContext.parentSpanID,
                operationName: self.operationName,
                startTime: self.startTime,
                finishTime: finishTime,
                samplingRate: self.kubesenseContext.sampleRate / 100.0,
                samplingPriority: self.kubesenseContext.samplingDecision.samplingPriority,
                samplingDecisionMaker: self.kubesenseContext.samplingDecision.decisionMaker,
                tags: self.tags,
                baggageItems: self.kubesenseContext.baggageItems.all,
                logFields: self.logFields
            )

            let envelope = SpanEventsEnvelope(span: event, environment: context.env)
            writer.write(value: envelope)
        }
    }

    private func sendSpanLogs(message: String?, fields: [String: Encodable], date: Date) {
        loggingIntegration.writeLog(withSpanContext: kubesenseContext, message: message, fields: fields, date: date, else: {
            DD.logger.warn("The log for span \"\(self.operationName)\" will not be send, because the Logs feature is not enabled.")
        })
    }

    // MARK: - Private

    private func warnIfFinished(_ methodName: String) -> Bool {
        warnIfFinished(methodName, isFinished: isFinished)
    }

    private func warnIfFinished(_ methodName: String, isFinished: Bool) -> Bool {
        return warn(
            if: isFinished,
            message: "🔥 Calling `\(methodName)` on a finished span (\"\(operationName)\") is not allowed."
        )
    }
}
