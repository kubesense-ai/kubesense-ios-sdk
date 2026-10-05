/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Kubesense addition to the fork of dd-sdk-ios, see docs/UPSTREAM_SYNC.md.
 */

import KubesenseRUM
import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var store: ShopStore
    @EnvironmentObject private var router: ShopRouter

    var body: some View {
        let results = store.filteredProducts
        List {
            Section {
                TextField("Search products or categories", text: $store.query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Text("\(results.count) results").font(.footnote).foregroundStyle(.secondary)
            }
            if results.isEmpty {
                EmptyStateView(title: "No products found", message: "Try another name or category")
                    .listRowBackground(Color.clear)
            } else {
                ForEach(results) { product in
                    HStack(spacing: 12) {
                        SquareProductArt(product: product, size: 76)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.title).font(.subheadline.bold())
                            Text("\(product.category) · ★ \(ShopFormat.rating(product.rating))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Add") {
                            store.addToCart(product.id)
                            router.openCart()
                        }
                        .buttonStyle(.bordered)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { router.push(.product(product.id)) }
                }
            }
        }
        .navigationTitle("Find your next favorite")
        .trackRUMView(name: "search")
    }
}
