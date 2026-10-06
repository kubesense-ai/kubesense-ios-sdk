/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

#if canImport(UIKit) && !os(watchOS)
import UIKit
import KubesenseInternal

internal final class KubesenseApplicationInstrumentation {
    let sendEvent: SendEvent

    init(handler: RUMActionsHandling) throws {
        sendEvent = try SendEvent(handler: handler)
    }

    func install() {
        sendEvent.swizzle()
    }

    internal func uninstall() {
        sendEvent.unswizzle()
    }

    deinit {
        sendEvent.unswizzle()
    }

    // MARK: - Swizzlings

    /// Swizzles the `KubesenseApplication.sendEvent(_:)`
    class SendEvent: MethodSwizzler <
        @convention(c) (KubesenseApplication, Selector, KubesenseEvent) -> Bool,
        @convention(block) (KubesenseApplication, KubesenseEvent) -> Bool
    > {
        private static let selector = #selector(KubesenseApplication.sendEvent(_:))
        private let method: Method
        private let handler: RUMActionsHandling

        init(handler: RUMActionsHandling) throws {
            self.method = try kubesense_class_getInstanceMethod(KubesenseApplication.self, Self.selector)
            self.handler = handler
        }

        func swizzle() {
            typealias Signature = @convention(block) (KubesenseApplication, KubesenseEvent) -> Bool
            swizzle(method) { previousImplementation -> Signature in
                return { [weak handler = self.handler] application, event  in
                    handler?.notify_sendEvent(application: application, event: event)
                    return previousImplementation(application, Self.selector, event)
                }
            }
        }
    }
}
#endif
