/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Kubesense addition to the fork of dd-sdk-ios, see docs/UPSTREAM_SYNC.md.
 */

import Foundation

struct Product: Identifiable, Equatable, Codable {
    let id: Int
    let title: String
    let description: String
    let price: Double
    let category: String
    let rating: Double
    let thumbnail: String

    init(id: Int, title: String, description: String, price: Double, category: String, rating: Double, thumbnail: String? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.price = price
        self.category = category
        self.rating = rating
        self.thumbnail = (thumbnail?.isEmpty == false) ? thumbnail! : ProductImages.forProduct(id)
    }
}

enum ProductImages {
    private static let photos = [
        "photo-1505740420928-5e560c06d30e",
        "photo-1507473885765-e6ed057f782c",
        "photo-1553062407-98eeb64c6a62",
        "photo-1530968831187-a937ade474cb",
        "photo-1587829741301-dc798b83add3",
        "photo-1542291026-7eec264c27ff",
        "photo-1608043152269-423dbba4e7e1",
        "photo-1602143407151-7111542de6e8",
    ]

    static func url(at index: Int) -> String {
        "https://images.unsplash.com/\(photos[index])?auto=format&fit=crop&w=900&q=85"
    }

    static func forProduct(_ id: Int) -> String {
        url(at: ((id - 1) % photos.count + photos.count) % photos.count)
    }
}

enum DataOrigin {
    case live
    case fallback
}

struct ProductCatalog {
    var products: [Product]
    var origin: DataOrigin
    var message: String?
    var page = 1
    var total: Int
    var hasMore = false
}

/// The `/products` envelope. Every field is optional: items without a title are dropped.
struct ProductEnvelope: Decodable {
    struct ApiProduct: Decodable {
        let id: Int?
        let title: String?
        let description: String?
        let price: Double?
        let category: String?
        let rating: Double?
        let thumbnail: String?

        var product: Product? {
            guard let id, let title, !title.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            return Product(
                id: id,
                title: title,
                description: description ?? "",
                price: price ?? 0,
                category: category ?? "",
                rating: rating ?? 0,
                thumbnail: thumbnail
            )
        }
    }

    let products: [ApiProduct]?
    let page: Int?
    let limit: Int?
    let total: Int?
    let hasMore: Bool?
}

struct AuthUser: Codable, Equatable {
    let id: String
    let name: String
    let email: String
}

struct AuthSession {
    let user: AuthUser
    let token: String
}

struct OrderItem: Codable, Equatable {
    let productId: Int
    let title: String
    let quantity: Int
    let price: Double
}

struct Order: Codable, Identifiable, Equatable {
    let id: String
    let total: Double
    let status: String
    let createdAt: String
    let items: [OrderItem]
}

enum ShopFormat {
    static func price(_ value: Double) -> String {
        value.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }

    static func rating(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}
