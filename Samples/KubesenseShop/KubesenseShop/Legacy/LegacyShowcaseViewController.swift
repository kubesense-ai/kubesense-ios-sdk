/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Kubesense addition to the fork of dd-sdk-ios, see docs/UPSTREAM_SYNC.md.
 */

import KubesenseRUM
import KubesenseWebViewTracking
import SwiftUI
import UIKit
import WebKit

/// A UIKit screen with classic controls and an embedded web page: auto-tracked as a RUM view by
/// class name, recorded by Session Replay (the secure field is masked), and bridged to the web.
final class LegacyShowcaseViewController: UIViewController {
    private let slider = UISlider()
    private let webView = WKWebView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "UIKit views showcase"
        view.backgroundColor = .systemBackground

        let heading = UILabel()
        heading.text = "UIKit views workshop"
        heading.font = .preferredFont(forTextStyle: .title1).withTraits(.traitBold)
        heading.numberOfLines = 0

        let subtitle = UILabel()
        subtitle.text = "A replay-friendly collection of classic UIKit controls."
        subtitle.textColor = .secondaryLabel
        subtitle.numberOfLines = 0

        let note = UITextField()
        note.placeholder = "Private note"
        note.text = "masked checkout note"
        note.isSecureTextEntry = true
        note.borderStyle = .roundedRect

        slider.minimumValue = 1
        slider.maximumValue = 5
        slider.value = 2
        slider.addTarget(self, action: #selector(snapSlider), for: .valueChanged)

        let delivery = UISegmentedControl(items: ["Standard", "Express"])
        delivery.selectedSegmentIndex = 0

        var buttonConfiguration = UIButton.Configuration.filled()
        buttonConfiguration.title = "Send legacy-view action"
        let send = UIButton(configuration: buttonConfiguration)
        send.addTarget(self, action: #selector(sendAction), for: .touchUpInside)

        webView.heightAnchor.constraint(equalToConstant: 260).isActive = true
        webView.layer.cornerRadius = 12
        webView.clipsToBounds = true
        if KubesenseSetup.sdkEnabled {
            WebViewTracking.enable(webView: webView, hosts: ["www.kubesense.ai"])
        }
        webView.loadHTMLString(
            """
            <html><head><meta name='viewport' content='width=device-width'></head>\
            <body style='font-family:sans-serif;padding:20px;background:#eef7f3'><h2>Web checkout</h2>\
            <p>This embedded surface validates WebView and replay capture.</p>\
            <button style='padding:12px'>Continue securely</button></body></html>
            """,
            baseURL: URL(string: "https://www.kubesense.ai/sample")
        )

        let stack = UIStackView(arrangedSubviews: [heading, subtitle, note, slider, delivery, send, webView])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -24),
        ])
    }

    deinit {
        if KubesenseSetup.sdkEnabled {
            WebViewTracking.disable(webView: webView)
        }
    }

    @objc private func snapSlider() {
        slider.value = slider.value.rounded()
    }

    @objc private func sendAction() {
        RUMMonitor.shared().addAction(type: .tap, name: "legacy.checkout_option", attributes: ["quantity": Int(slider.value)])
    }
}

private extension UIFont {
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        fontDescriptor.withSymbolicTraits(traits).map { UIFont(descriptor: $0, size: 0) } ?? self
    }
}

/// Presents the UIKit screen inside its own navigation controller.
struct LegacyShowcaseScreen: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UINavigationController {
        UINavigationController(rootViewController: LegacyShowcaseViewController())
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {}
}
