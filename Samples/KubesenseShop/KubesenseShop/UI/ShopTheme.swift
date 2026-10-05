/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Kubesense addition to the fork of dd-sdk-ios, see docs/UPSTREAM_SYNC.md.
 */

import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum ShopTheme {
    static let primary = Color("AccentColor")
    static let primaryContainer = Color(hex: 0xE8DFFF)
    static let background = Color(hex: 0xFBF9FF)
    static let surfaceVariant = Color(hex: 0xE9E2EF)
    static let secondary = Color(hex: 0x5D526F)

    static let heroGradient = LinearGradient(
        colors: [Color(hex: 0x0B4239), Color(hex: 0x398D78), Color(hex: 0xF0B67F)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func productGradient(for id: Int) -> LinearGradient {
        let pairs: [(UInt32, UInt32)] = [(0x8C5E58, 0xE1A77E), (0x315E55, 0x86B59E), (0x304C74, 0x88A7C7), (0x6E5A7D, 0xC9A7C9)]
        let pair = pairs[((id % 4) + 4) % 4]
        return LinearGradient(colors: [Color(hex: pair.0), Color(hex: pair.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// Product photo on a gradient, or the title's initial when there is no photo.
struct ProductArt: View {
    let product: Product
    var height: CGFloat
    var cornerRadius: CGFloat = 18

    var body: some View {
        // The photo is an overlay so its fill scaling never widens the card.
        ShopTheme.productGradient(for: product.id)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay {
                if let url = URL(string: product.thumbnail), !product.thumbnail.isEmpty {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        }
                    }
                } else {
                    Circle()
                        .fill(.white.opacity(0.22))
                        .frame(width: height * 0.45, height: height * 0.45)
                        .overlay(Text(product.title.prefix(1)).font(.title.bold()).foregroundStyle(.white))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct SquareProductArt: View {
    let product: Product
    let size: CGFloat
    var cornerRadius: CGFloat = 14

    var body: some View {
        ProductArt(product: product, height: size, cornerRadius: cornerRadius).frame(width: size)
    }
}

struct StatusCard: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(ShopTheme.primaryContainer, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(.title3.bold())
            Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(.white)
            .background(ShopTheme.primary.opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.35), in: Capsule())
    }
}
