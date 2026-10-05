/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Kubesense addition to the fork of dd-sdk-ios, see docs/UPSTREAM_SYNC.md.
 */

import KubesenseRUM
import SwiftUI

@main
struct KubesenseShopApp: App {
    @StateObject private var store: ShopStore

    init() {
        let config = ShopConfig.load()
        KubesenseSetup.start(with: config)
        _store = StateObject(wrappedValue: ShopStore(config: config))
    }

    var body: some Scene {
        WindowGroup {
            ShopRootView()
                .environmentObject(store)
                .onAppear { RUMMonitor.shared().reportAppFullyDisplayed() }
        }
    }
}
