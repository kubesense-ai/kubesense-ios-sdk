/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Kubesense addition to the fork of dd-sdk-ios, see docs/UPSTREAM_SYNC.md.
 */

import KubesenseRUM
import SwiftUI

struct ProductDetailView: View {
    @EnvironmentObject private var store: ShopStore
    @EnvironmentObject private var router: ShopRouter
    let productID: Int

    var body: some View {
        Group {
            if let product = store.products.first(where: { $0.id == productID }) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ProductArt(product: product, height: 330, cornerRadius: 0)
                        VStack(alignment: .leading, spacing: 10) {
                            Text(product.category.uppercased()).font(.caption.bold()).foregroundStyle(.secondary)
                            Text(product.title).font(.largeTitle.weight(.black))
                            Text("★ \(ShopFormat.rating(product.rating))  ·  Designed for everyday use")
                                .foregroundStyle(ShopTheme.secondary)
                            Text(product.description)
                            HStack {
                                Text(ShopFormat.price(product.price)).font(.title2.bold())
                                Spacer()
                                Button("Add to cart") {
                                    store.addToCart(product.id)
                                    router.openCart()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                            }
                            .padding(.top, 8)
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .ignoresSafeArea(edges: .top)
            } else {
                EmptyStateView(title: "Product unavailable", message: "Go back and refresh the catalog.")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .trackRUMView(name: "product/{id}", attributes: ["view.arguments.id": productID])
    }
}
