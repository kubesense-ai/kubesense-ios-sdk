/*
* Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
* This product includes software developed at Datadog (https://www.datadoghq.com/).
* Copyright 2019-Present Datadog, Inc.
*/

import Foundation
import OpenTelemetryApi
import KubesenseInternal

extension OpenTelemetryApi.TraceId {
    /// Converts OpenTelemetry `TraceId` to Kubesense `TraceID`.
    /// - Returns: Kubesense `TraceID` with only higher order bits considered.
    func toKubesense() -> TraceID {
        return .init(idHi: self.idHi, idLo: self.idLo)
    }
}
