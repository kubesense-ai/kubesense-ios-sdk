/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

@testable import KubesenseTrace

/*
 NOTE: The casting methods defined here do shadow the ones defined in `Kubesense.Casting`.
 The difference is that here in tests we do force unwrapping (`as!`), whereas in `Kubesense` we do `as?` with a warning.

 This is needed for expressiveness in testing, where i.e. `XCTAssertNil(span.context.kubesense?.parentID)` may give a false positive
 without considering if the `parentID` is `nil`. Using `span.context.kubesense.parentID` mitigates it.
 */

internal extension OTTracer {
    var kubesense: KubesenseTracer { self as! KubesenseTracer }
}

internal extension OTSpan {
    var kubesense: KubesenseSpan { self as! KubesenseSpan }
}

internal extension OTSpanContext {
    var kubesense: KubesenseSpanContext { self as! KubesenseSpanContext }
}
