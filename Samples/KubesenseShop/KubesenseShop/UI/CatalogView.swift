/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Kubesense addition to the fork of dd-sdk-ios, see docs/UPSTREAM_SYNC.md.
 */

import KubesenseRUM
import SwiftUI

struct CatalogView: View {
    @EnvironmentObject private var store: ShopStore
    @EnvironmentObject private var router: ShopRouter

    private let columns = [GridItem(.adaptive(minimum: 168), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                LazyVGrid(columns: columns, spacing: 14) {
                    if store.loading && store.products.isEmpty {
                        ForEach(0..<8, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(ShopTheme.surfaceVariant)
                                .frame(height: 228)
                                .id("skeleton-\(index)")
                        }
                    } else {
                        ForEach(store.products) { product in
                            ProductCard(product: product)
                                .id("product-\(product.id)")
                                .onAppear {
                                    if store.products.suffix(5).contains(where: { $0.id == product.id }) {
                                        Task { await store.loadMoreProducts() }
                                    }
                                }
                        }
                    }
                }
                if store.productsLoadingMore {
                    ProgressView().frame(maxWidth: .infinity).padding()
                }
            }
            .padding(16)
        }
        .background(ShopTheme.background)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 10) {
                    Image("KubesenseLogoBlack").resizable().scaledToFit().frame(width: 32, height: 32)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Kubesense Shop").font(.headline.bold())
                        Text("Objects for thoughtful everyday living").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await store.refresh() }
        .trackRUMView(name: "shop")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HeroCard()
            HStack {
                let label = store.origin == .live ? "Live catalog" : "Offline collection"
                Text("\(label) · \(store.products.count)/\(store.productsTotal)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ShopTheme.secondary)
                Spacer()
                Button("Refresh") { Task { await store.refresh() } }
            }
            if let notice = store.notice {
                HStack {
                    Text(notice).font(.footnote)
                    Spacer()
                    Button("Retry") { Task { await store.refresh() } }
                }
                .padding(14)
                .background(ShopTheme.surfaceVariant, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }
}

private struct HeroCard: View {
    var body: some View {
        ZStack(alignment: .leading) {
            ShopTheme.heroGradient
            HStack {
                Spacer()
                Image("KubesenseLogoTransparent").resizable().scaledToFit().frame(width: 170).opacity(0.18)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("THE FIELD EDIT").font(.caption.bold()).kerning(2).foregroundStyle(Color(hex: 0xBDF4DF))
                Text("Less clutter.\nBetter rituals.")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text("A calm collection built to move with you.").font(.subheadline).foregroundStyle(.white.opacity(0.84))
            }
            .padding(20)
        }
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct ProductCard: View {
    @EnvironmentObject private var store: ShopStore
    @EnvironmentObject private var router: ShopRouter
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { router.push(.product(product.id)) } label: {
                VStack(alignment: .leading, spacing: 6) {
                    ProductArt(product: product, height: 150)
                    Text(product.category.uppercased()).font(.caption2.bold()).foregroundStyle(.secondary)
                    Text(product.title).font(.subheadline.bold()).lineLimit(1).foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)
            HStack {
                Text(ShopFormat.price(product.price)).font(.subheadline.weight(.semibold))
                Spacer()
                Button("Add") {
                    store.addToCart(product.id)
                    router.openCart()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .trackRUMTapAction(name: "Add \(product.title) to cart")
            }
        }
        .padding(10)
        .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
