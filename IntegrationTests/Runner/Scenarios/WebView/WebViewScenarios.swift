/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import UIKit
import KubesenseCore
@testable import KubesenseRUM
@testable import KubesenseLogs
@testable import KubesenseSessionReplay

private struct WebViewTrackingScenarioPredicate: UIKitRUMViewsPredicate {
    private let defaultPredicate = DefaultUIKitRUMViewsPredicate()

    func rumView(for viewController: UIViewController) -> RUMView? {
        if viewController is ShopistWebviewViewController {
            return nil // do not consider the webview itself as RUM view
        }
        // Exclude Screen Time view controllers (ST-prefixed) injected by iOS on top of WKWebView.
        if String(describing: type(of: viewController)).hasPrefix("ST") {
            return nil
        }
        return defaultPredicate.rumView(for: viewController)
    }
}

final class WebViewTrackingScenario: TestScenario {
    static var storyboardName: String = "WebViewTrackingScenario"

    func configureFeatures() {
        var rumConfig = RUM.Configuration(
            applicationID: "rum-application-id",
            uiKitViewsPredicate: WebViewTrackingScenarioPredicate()
        )
        rumConfig.customEndpoint = Environment.serverMockConfiguration()?.rumEndpoint
        RUM.enable(with: rumConfig)

        var srConfig = SessionReplay.Configuration(replaySampleRate: 100)
        srConfig.customEndpoint = Environment.serverMockConfiguration()?.srEndpoint
        SessionReplay.enable(with: srConfig)

        var logsConfig = Logs.Configuration()
        logsConfig.customEndpoint = Environment.serverMockConfiguration()?.logsEndpoint
        Logs.enable(with: logsConfig)
    }
}
