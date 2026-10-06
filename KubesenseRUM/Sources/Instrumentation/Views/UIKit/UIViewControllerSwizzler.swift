/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

#if !os(watchOS) && canImport(UIKit)
import UIKit
import KubesenseInternal

internal class KubesenseViewControllerSwizzler {
    let viewDidAppear: ViewDidAppear
    let viewDidDisappear: ViewDidDisappear

    init(handler: UIViewControllerHandler) throws {
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
        @convention(c) (KubesenseViewController, Selector, Bool) -> Void,
        @convention(block) (KubesenseViewController, Bool) -> Void
    > {
        private static let selector = #selector(KubesenseViewController.viewDidAppear(_:))
        private let method: Method
        private let handler: UIViewControllerHandler

        init(handler: UIViewControllerHandler) throws {
            self.method = try kubesense_class_getInstanceMethod(KubesenseViewController.self, Self.selector)
            self.handler = handler
        }

        func swizzle() {
            typealias Signature = @convention(block) (KubesenseViewController, Bool) -> Void
            swizzle(method) { previousImplementation -> Signature in
                return { [weak handler = self.handler] vc, animated  in
                    handler?.notify_viewDidAppear(viewController: vc, animated: animated)
                    previousImplementation(vc, Self.selector, animated)
                }
            }
        }
    }

    /// Swizzles the `KubesenseViewController.viewDidDisappear()`
    class ViewDidDisappear: MethodSwizzler <
        @convention(c) (KubesenseViewController, Selector, Bool) -> Void,
        @convention(block) (KubesenseViewController, Bool) -> Void
    > {
        private static let selector = #selector(KubesenseViewController.viewDidDisappear(_:))
        private let method: Method
        private let handler: UIViewControllerHandler

        init(handler: UIViewControllerHandler) throws {
            self.method = try kubesense_class_getInstanceMethod(KubesenseViewController.self, Self.selector)
            self.handler = handler
        }

        func swizzle() {
            typealias Signature = @convention(block) (KubesenseViewController, Bool) -> Void
            swizzle(method) { previousImplementation -> Signature in
                return { [weak handler = self.handler] vc, animated  in
                    handler?.notify_viewDidDisappear(viewController: vc, animated: animated)
                    previousImplementation(vc, Self.selector, animated)
                }
            }
        }
    }
}
#endif
