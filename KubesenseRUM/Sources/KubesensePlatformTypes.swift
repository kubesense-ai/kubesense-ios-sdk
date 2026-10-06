/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

/// Platform-agnostic type aliases bridging UIKit (iOS / tvOS / visionOS) and AppKit (macOS).
///
/// Use these aliases throughout KubesenseRUM to avoid `#if canImport(UIKit)` scatter in
/// implementation files. Types with no meaningful AppKit equivalent (e.g. `UIAccessibility`,
/// `UIContentSizeCategory`, `UIPress`, `UIDevice`) are intentionally excluded and must be
/// guarded at the call site with `#if canImport(UIKit)`.

#if canImport(UIKit)
import UIKit
#if !os(watchOS)

// MARK: - Application
internal typealias KubesenseApplication = UIApplication

// MARK: - Views
internal typealias KubesenseView = UIView
internal typealias KubesenseControl = UIControl
internal typealias KubesenseLabel = UILabel
internal typealias KubesenseButton = UIButton
internal typealias KubesenseScrollView = UIScrollView
internal typealias KubesenseStackView = UIStackView
internal typealias KubesenseSegmentedControl = UISegmentedControl
internal typealias KubesenseWindow = UIWindow
#if !os(visionOS)
internal typealias KubesenseScreen = UIScreen
#endif

// MARK: - View Controllers
internal typealias KubesenseViewController = UIViewController

// MARK: - Events
internal typealias KubesenseEvent = UIEvent
internal typealias KubesenseTouch = UITouch

// MARK: - Collection / Table Cells
internal typealias KubesenseTableViewCell = UITableViewCell
internal typealias KubesenseCollectionViewCell = UICollectionViewCell

// MARK: - Accessibility
internal typealias KubesenseAccessibility = UIAccessibility

internal typealias KubesenseKitRUMActionsPredicate = UIKitRUMActionsPredicate
internal typealias KubesenseKitRUMViewsPredicate = UIKitRUMViewsPredicate
#endif

// MARK: - Appearance
internal typealias KubesenseColor = UIColor
internal typealias KubesenseFont = UIFont

#if canImport(SwiftUI) && (os(iOS) || os(tvOS) || os(visionOS))
import SwiftUI

@available(iOS 13.0, tvOS 13.0, *)
internal typealias KubesenseHostingController = UIHostingController
#endif

#elseif canImport(AppKit)
import AppKit

// MARK: - Application
internal typealias KubesenseApplication = NSApplication

// MARK: - Views
internal typealias KubesenseView = NSView
internal typealias KubesenseControl = NSControl
/// Closest AppKit equivalent; configure with `isEditable = false` / `isBezeled = false` for label behaviour.
internal typealias KubesenseLabel = NSTextField
internal typealias KubesenseButton = NSButton
internal typealias KubesenseScrollView = NSScrollView
internal typealias KubesenseStackView = NSStackView
internal typealias KubesenseSegmentedControl = NSSegmentedControl
internal typealias KubesenseWindow = NSWindow
internal typealias KubesenseScreen = NSScreen

// MARK: - View Controllers
internal typealias KubesenseViewController = NSViewController

// MARK: - Events
/// `NSEvent` covers all input events on macOS (mouse, keyboard, scroll, etc.).
internal typealias KubesenseEvent = NSEvent
/// `NSTouch` represents trackpad touches on macOS; semantically different from `UITouch`.
internal typealias KubesenseTouch = NSTouch

// MARK: - Appearance
internal typealias KubesenseColor = NSColor
internal typealias KubesenseFont = NSFont

// MARK: - Collection / Table Cells
/// Closest AppKit equivalent to `UITableViewCell` — an `NSView`-based cell.
internal typealias KubesenseTableViewCell = NSTableCellView
/// `NSCollectionViewItem` is the AppKit equivalent; note it is an `NSViewController` subclass.
internal typealias KubesenseCollectionViewCell = NSCollectionViewItem

// MARK: - Accessibility
/// Stub namespace matching `UIAccessibility` API surface used in KubesenseRUM.
/// AppKit exposes accessibility via `NSAccessibility` (a protocol) and top-level functions;
/// this enum provides a compilation target — actual macOS values are not supported.
internal typealias KubesenseAccessibility = NSAccessibility

// MARK: - Application lifecycle notifications
/// Maps `UIApplication.didEnterBackgroundNotification` → `NSApplication.didResignActiveNotification`.
extension NSApplication {
    static var didEnterBackgroundNotification: Notification.Name { NSApplication.didResignActiveNotification }
    static var willEnterForegroundNotification: Notification.Name { NSApplication.didBecomeActiveNotification }
}

// MARK: - SDK specific
internal typealias KubesenseKitRUMActionsPredicate = MacOSRUMActionsPredicate
internal typealias KubesenseKitRUMViewsPredicate = AppKitRUMViewsPredicate

#if canImport(SwiftUI)
import SwiftUI

internal typealias KubesenseHostingController = NSHostingController
#endif

#endif
