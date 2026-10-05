/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Kubesense addition to the fork of dd-sdk-ios, see docs/UPSTREAM_SYNC.md.
 */

import Foundation
import KubesenseCore

/// The app state, ported from the Android sample's `ShopViewModel`.
@MainActor
final class ShopStore: ObservableObject {
    @Published var loading = true
    @Published var products: [Product] = []
    @Published var productsLoadingMore = false
    @Published var productsHasMore = false
    @Published var productsPage = 1
    @Published var productsTotal = 0
    @Published var cart: [Int: Int] = [:]
    @Published var query = ""
    @Published var origin: DataOrigin = .fallback
    @Published var notice: String?
    @Published var checkoutInProgress = false
    @Published var user: AuthUser?
    @Published var authMessage: String?
    @Published var authInProgress = false
    @Published var orders: [Order] = []
    @Published var ordersLoading = false
    @Published var orderMessage: String?

    let config: ShopConfig
    private let repository: CommerceRepository
    private let sessionStore: ShopSessionStore
    private var token: String?

    var cartCount: Int { cart.values.reduce(0, +) }

    var filteredProducts: [Product] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return products }
        return products.filter {
            $0.title.localizedCaseInsensitiveContains(needle) || $0.category.localizedCaseInsensitiveContains(needle)
        }
    }

    /// Cart lines for products already loaded; items not yet paged in are left out, as on Android.
    var cartLines: [(product: Product, quantity: Int)] {
        products.compactMap { product in cart[product.id].map { (product, $0) } }
    }

    var cartTotal: Double { cartLines.reduce(0) { $0 + $1.product.price * Double($1.quantity) } }

    init(config: ShopConfig, repository: CommerceRepository? = nil, sessionStore: ShopSessionStore = ShopSessionStore()) {
        self.config = config
        self.repository = repository ?? CommerceRepository(baseURL: config.sampleApiBaseURL)
        self.sessionStore = sessionStore
        cart = sessionStore.cart
        user = sessionStore.user
        token = sessionStore.token
        if let user, token != nil {
            Kubesense.setUserInfo(
                id: user.id,
                name: user.name,
                email: user.email,
                extraInfo: ["source": "kubesense-shop", "auth.action": "restored"]
            )
        }
        Task { await refresh() }
    }

    // MARK: - Catalog

    func refresh() async {
        loading = true
        notice = nil
        let catalog = await repository.loadProducts(page: 1)
        products = catalog.products
        origin = catalog.origin
        notice = catalog.message
        productsPage = catalog.page
        productsTotal = catalog.total
        productsHasMore = catalog.hasMore
        loading = false
    }

    func loadMoreProducts() async {
        guard !loading, !productsLoadingMore, productsHasMore else { return }
        productsLoadingMore = true
        let catalog = await repository.loadProducts(page: productsPage + 1)
        var seen = Set(products.map(\.id))
        products += catalog.products.filter { seen.insert($0.id).inserted }
        origin = catalog.origin
        notice = catalog.message
        productsPage = catalog.page
        productsTotal = catalog.total
        productsHasMore = catalog.hasMore
        productsLoadingMore = false
    }

    // MARK: - Cart

    func addToCart(_ productID: Int) {
        cart[productID, default: 0] += 1
        cartChanged()
    }

    func removeFromCart(_ productID: Int) {
        guard let quantity = cart[productID] else { return }
        cart[productID] = quantity <= 1 ? nil : quantity - 1
        cartChanged()
    }

    private func cartChanged() {
        sessionStore.saveCart(cart)
        orderMessage = nil
    }

    func checkout(onSuccess: @escaping () -> Void) async {
        guard let token else {
            orderMessage = "Sign in before placing an order"
            return
        }
        checkoutInProgress = true
        defer { checkoutInProgress = false }
        switch await repository.createOrder(token: token, cart: cart, products: products) {
        case .failure(let error):
            orderMessage = error.message
        case .success(let created):
            cart = [:]
            orders = created + orders
            sessionStore.saveCart(cart)
            onSuccess()
        }
    }

    func loadOrders() async {
        guard let token else {
            orders = []
            orderMessage = "Sign in to view orders"
            return
        }
        ordersLoading = true
        defer { ordersLoading = false }
        switch await repository.loadOrders(token: token) {
        case .failure(let error): orderMessage = error.message
        case .success(let loaded): orders = loaded
        }
    }

    // MARK: - Account

    func register(name: String, email: String, password: String, onSuccess: @escaping () -> Void) async {
        let email = email.trimmingCharacters(in: .whitespaces).lowercased()
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            authMessage = "Enter your name"
        } else if !email.contains("@") {
            authMessage = "Enter a valid email"
        } else if password.count < 6 {
            authMessage = "Password must contain at least 6 characters"
        } else {
            authMessage = "Creating account…"
            authInProgress = true
            let result = await repository.register(name: name.trimmingCharacters(in: .whitespaces), email: email, password: password)
            authInProgress = false
            applyAuthResult(result, action: "registered", onSuccess: onSuccess)
        }
    }

    func login(email: String, password: String, onSuccess: @escaping () -> Void) async {
        let email = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard email.contains("@"), !password.isEmpty else {
            authMessage = "Enter your email and password"
            return
        }
        authMessage = "Signing in…"
        authInProgress = true
        let result = await repository.login(email: email, password: password)
        authInProgress = false
        applyAuthResult(result, action: "signed in", onSuccess: onSuccess)
    }

    func logout() {
        token = nil
        sessionStore.clearAuthentication()
        Kubesense.clearUserInfo()
        user = nil
        orders = []
        authMessage = "Signed out; SDK user context cleared"
    }

    private func applyAuthResult(_ result: Result<AuthSession, ShopError>, action: String, onSuccess: () -> Void) {
        switch result {
        case .failure(let error):
            authMessage = error.message
        case .success(let session):
            token = session.token
            sessionStore.saveAuthentication(session)
            Kubesense.setUserInfo(
                id: session.user.id,
                name: session.user.name,
                email: session.user.email,
                extraInfo: ["source": "kubesense-shop", "auth.action": action]
            )
            user = session.user
            authMessage = "\(session.user.name) \(action); SDK user context updated"
            onSuccess()
        }
    }
}
