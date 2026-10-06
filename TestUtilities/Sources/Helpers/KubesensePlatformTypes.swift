/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import Foundation

#if canImport(UIKit)
import UIKit

public typealias KubesenseColor = UIColor
#if !os(watchOS)
public typealias KubesenseView = UIView
#endif
#elseif canImport(AppKit)
import AppKit

public typealias KubesenseColor = NSColor
public typealias KubesenseView = NSView
#endif
