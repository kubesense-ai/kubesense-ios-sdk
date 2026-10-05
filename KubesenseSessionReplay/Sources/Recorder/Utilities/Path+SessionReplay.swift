/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

#if os(iOS)

import KubesenseInternal
import Foundation
import SwiftUI

extension SwiftUI.Path: KubesenseExtended {}

extension KubesenseExtension where ExtendedType == SwiftUI.Path {
    var svgString: String {
        var d = ""
        type.forEach { element in
            switch element {
            case let .move(to):
                d += "M \(to.kubesense.svgString) "
            case let .line(to):
                d += "L \(to.kubesense.svgString) "
            case let .quadCurve(to, control):
                d += "Q \(control.kubesense.svgString) \(to.kubesense.svgString) "
            case let .curve(to, control1, control2):
                d += "C \(control1.kubesense.svgString) \(control2.kubesense.svgString) \(to.kubesense.svgString) "
            case .closeSubpath:
                d += "Z "
            }
        }
        return d.trimmingCharacters(in: .whitespaces)
    }
}

extension CGPoint: KubesenseExtended {}

extension KubesenseExtension where ExtendedType == CGPoint {
    internal var svgString: String {
        "\(type.x.kubesense.svgString) \(type.y.kubesense.svgString)"
    }
}

extension CGFloat: KubesenseExtended {}

extension KubesenseExtension where ExtendedType == CGFloat {
    internal var svgString: String {
        String(format: "%.3f", type)
    }
}

#endif
