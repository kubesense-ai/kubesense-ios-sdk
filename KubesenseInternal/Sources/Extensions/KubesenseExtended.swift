/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import Foundation

/// Type that acts as a generic extension point for all `KubesenseExtended` types.
public struct KubesenseExtension<ExtendedType> {
    /// Stores the type or meta-type of any extended type.
    public private(set) var type: ExtendedType

    /// Create an instance from the provided value.
    ///
    /// - Parameter type: Instance being extended.
    public init(_ type: ExtendedType) {
        self.type = type
    }
}

/// Protocol describing the `dd` extension points for Kubesense extended types.
public protocol KubesenseExtended {
    /// Type being extended.
    associatedtype ExtendedType

    /// Static Kubesense extension point.
    static var dd: KubesenseExtension<ExtendedType>.Type { get set }
    /// Instance Kubesense extension point.
    var dd: KubesenseExtension<ExtendedType> { get set }
}

extension KubesenseExtended {
    /// Static Kubesense extension point.
    public static var dd: KubesenseExtension<Self>.Type {
        get { KubesenseExtension<Self>.self }
        set {}
    }

    /// Instance Kubesense extension point.
    public var dd: KubesenseExtension<Self> {
        get { KubesenseExtension(self) }
        set {}
    }
}

extension Array: KubesenseExtended {}
extension Dictionary: KubesenseExtended {}
