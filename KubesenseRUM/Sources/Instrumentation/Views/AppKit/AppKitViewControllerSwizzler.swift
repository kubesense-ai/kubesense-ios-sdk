/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
import KubesenseInternal

internal class KubesenseViewControllerSwizzler {
    let viewDidAppear: ViewDidAppear
    let viewDidDisappear: ViewDidDisappear

    init(handler: NSViewControllerHandler) throws {
        self.viewDidAppear = try ViewDidAppear(handler: handler)
        self.viewDidDisappear = try ViewDidDisappear(handler: handler)
    }

    func swizzle() {
        viewDidAppear.swizzle()
        viewDidDisappear.swizzle()
    }

    internal func unswizzle() {
        viewDidAppear.unswizzle()
        viewDidDisappear.unswizzle()
    }

    // MARK: - Swizzlings

    /// Swizzles the `KubesenseViewController.viewDidAppear()`
    class ViewDidAppear: MethodSwizzler <
        @convention(c) (KubesenseViewController, Selector) -> Void,
        @convention(block) (KubesenseViewController) -> Void
    > {
        private static let selector = #selector(KubesenseViewController.viewDidAppear)
        private let method: Method
        private let handler: NSViewControllerHandler

        init(handler: NSViewControllerHandler) throws {
            self.method = try kubesense_class_getInstanceMethod(KubesenseViewController.self, Self.selector)
            self.handler = handler
        }

        func swizzle() {
            typealias Signature = @convention(block) (KubesenseViewController) -> Void
            swizzle(method) { previousImplementation -> Signature in
                return { [weak handler = self.handler] vc in
                    handler?.notify_viewDidAppear(viewController: vc)
                    previousImplementation(vc, Self.selector)
                }
            }
        }
    }

    /// Swizzles the `KubesenseViewController.viewDidDisappear()`
    class ViewDidDisappear: MethodSwizzler <
        @convention(c) (KubesenseViewController, Selector) -> Void,
        @convention(block) (KubesenseViewController) -> Void
    > {
        private static let selector = #selector(KubesenseViewController.viewDidDisappear)
        private let method: Method
        private let handler: NSViewControllerHandler

        init(handler: NSViewControllerHandler) throws {
            self.method = try kubesense_class_getInstanceMethod(KubesenseViewController.self, Self.selector)
            self.handler = handler
        }

        func swizzle() {
            typealias Signature = @convention(block) (KubesenseViewController) -> Void
            swizzle(method) { previousImplementation -> Signature in
                return { [weak handler = self.handler] vc  in
                    handler?.notify_viewDidDisappear(viewController: vc)
                    previousImplementation(vc, Self.selector)
                }
            }
        }
    }
}

#endif
