/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import Foundation

/// Trace propagation headers as explained in
/// https://docs.kubesense.ai/real_user_monitoring/connect_rum_and_traces/?tab=browserrum#how-are-rum-resources-linked-to-traces
public enum TracingHTTPHeaders {
    /// Trace propagation header.
    /// It is used both in Tracing and RUM features.
    public static let traceIDField = "x-kubesense-trace-id"

    /// Trace propagation header.
    /// In RUM - it allows Kubesense to generate the first span from the trace.
    /// In Tracing - it injects the `spanID` of mobile span so downstream spans can be properly linked in distributed tracing.
    public static let parentSpanIDField = "x-kubesense-parent-id"

    /// To make sure that the Agent keeps the trace.
    /// It is used both in Tracing and RUM features.
    public static let samplingPriorityField = "x-kubesense-sampling-priority"

    /// The Kubesense origin of the Trace.
    ///
    /// Setting the value to 'rum' will indicate that the span is reported as a RUM Resource.
    public static let originField = "x-kubesense-origin"

    /// The Kubesense tags of the Trace.
    public static let tagsField = "x-kubesense-tags"

    /// Keys for Kubesense tags.
    public enum TagKeys {
        /// The Kubesense tag key for the higher order 64 bits of the trace ID.
        public static let traceIDHi = "_kubesense.p.tid"
    }
}
