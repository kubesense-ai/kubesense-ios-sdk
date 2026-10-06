/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

#if os(iOS)
import UIKit
import KubesenseInternal

internal struct UIImageResource {
    private let image: UIImage
    private let tintColor: UIColor?

    internal init(image: UIImage, tintColor: UIColor?) {
        self.image = image
        self.tintColor = tintColor
    }
}

extension UIImageResource: Resource {
    var mimeType: String {
        "image/png"
    }

    func calculateIdentifier() -> String {
        tintColor.map { image.kubesense.identifier + $0.kubesense.identifier } ?? image.kubesense.identifier
    }

    func calculateData() -> Data {
        image.kubesense.pngData(tintColor: tintColor) ?? Data()
    }
}
#endif
