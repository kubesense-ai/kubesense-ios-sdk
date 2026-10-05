/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Kubesense addition to the fork of dd-sdk-ios, see docs/UPSTREAM_SYNC.md.
 */

import Foundation

/// The offline catalog: 13 collections of the same 8 items, 104 products, generated the same way
/// as the sample API seeds its database, so offline and live listings line up.
enum FallbackCatalog {
    private static let baseItems: [(title: String, description: String, price: Double, category: String, rating: Double)] = [
        ("Terra headphones", "Spatial sound, soft-touch controls, and 40-hour battery life.", 149, "Audio", 4.8),
        ("Moss desk lamp", "A warm dimmable light with a compact recycled-aluminum base.", 79, "Home", 4.6),
        ("Orbit daypack", "Weatherproof everyday carry with a padded 16-inch laptop sleeve.", 118, "Travel", 4.9),
        ("Field ceramic set", "Four hand-finished mugs made for slow mornings and shared tables.", 64, "Kitchen", 4.7),
        ("Arc mechanical keyboard", "Low-profile tactile switches in a quiet aluminum chassis.", 169, "Workspace", 4.9),
        ("Drift trail shoes", "Responsive everyday trainers with a breathable knit upper.", 132, "Outdoors", 4.5),
        ("Halo portable speaker", "Room-filling sound in a water-resistant pocketable design.", 96, "Audio", 4.6),
        ("Fold travel bottle", "An insulated bottle that packs down when the day is done.", 38, "Travel", 4.4),
    ]

    static let products: [Product] = {
        var products: [Product] = []
        for collection in 0..<13 {
            for (index, base) in baseItems.enumerated() {
                let title = collection == 0 ? base.title : "\(base.title) · Edition \(collection + 1)"
                let rating: Double = base.rating - Double(collection % 3) * 0.1
                products.append(Product(
                    id: collection * baseItems.count + index + 1,
                    title: title,
                    description: base.description,
                    price: base.price + Double(collection) * 4,
                    category: base.category,
                    rating: max(4.1, (rating * 10).rounded() / 10),
                    thumbnail: ProductImages.url(at: index)
                ))
            }
        }
        return products
    }()

    static func page(_ page: Int, limit: Int, message: String) -> ProductCatalog {
        let offset = (page - 1) * limit
        let slice = Array(products.dropFirst(offset).prefix(limit))
        return ProductCatalog(
            products: slice,
            origin: .fallback,
            message: message,
            page: page,
            total: products.count,
            hasMore: offset + slice.count < products.count
        )
    }
}
