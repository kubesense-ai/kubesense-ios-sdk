/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import Foundation

/// The Kubesense sites the SDK can send data to.
///
/// Every feature uploads to the Kubesense RUM collector of the selected site, under
/// `https://<host>/rum/api/v1/...`. Set `Kubesense.Configuration.kubesenseRumEndpoint` to send data to
/// another collector host instead.
public enum KubesenseSite: String {
    /// The production site: [us2.kubesense.ai](https://us2.kubesense.ai).
    case prod
    /// The staging site (internal usage only): [dev.kubesense.ai](https://dev.kubesense.ai).
    case staging
}

extension KubesenseSite {
    /// The collector hostname for this site (e.g. `us2.kubesense.ai`).
    public var host: String {
        switch self {
        case .prod: return "us2.kubesense.ai"
        case .staging: return "dev.kubesense.ai"
        }
    }

    /// The collector base URL for this site (e.g. `https://us2.kubesense.ai/`).
    public var endpoint: URL {
        // swiftlint:disable:next force_unwrapping
        URL(string: "https://\(host)/")!
    }
}
