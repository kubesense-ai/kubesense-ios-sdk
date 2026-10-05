/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Kubesense addition to the fork of dd-sdk-ios, see docs/UPSTREAM_SYNC.md.
 */

import SwiftUI

enum ShopTab: Hashable {
    case shop, search, cart, account, diagnostics
}

enum ShopRoute: Hashable {
    case product(Int)
    case checkout
    case orders
    case order(String)
}

/// Tab selection and one navigation stack per tab, like the Android sample's top-level destinations.
@MainActor
final class ShopRouter: ObservableObject {
    @Published var tab: ShopTab = .shop
    @Published var paths: [ShopTab: [ShopRoute]] = [:]
    @Published var returnRouteAfterAuthentication: ShopRoute?

    func path(for tab: ShopTab) -> Binding<[ShopRoute]> {
        Binding(get: { self.paths[tab] ?? [] }, set: { self.paths[tab] = $0 })
    }

    func push(_ route: ShopRoute) {
        paths[tab, default: []].append(route)
    }

    func openCart() {
        tab = .cart
    }

    func continueToCheckout(signedIn: Bool) {
        if signedIn {
            paths[.cart] = [.checkout]
        } else {
            returnRouteAfterAuthentication = .checkout
            tab = .account
        }
    }

    func resumeAfterAuthentication() {
        guard let route = returnRouteAfterAuthentication else { return }
        returnRouteAfterAuthentication = nil
        if route == .checkout {
            paths[.cart] = [.checkout]
            tab = .cart
        }
    }

    /// After an order is placed: show the order history on top of the cart.
    func showOrdersAfterCheckout() {
        paths[.cart] = [.orders]
    }
}

struct ShopRootView: View {
    @EnvironmentObject private var store: ShopStore
    @StateObject private var router = ShopRouter()

    var body: some View {
        TabView(selection: $router.tab) {
            stack(.shop) { CatalogView() }
                .tabItem { Label("Shop", systemImage: "house") }
                .tag(ShopTab.shop)
            stack(.search) { SearchView() }
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(ShopTab.search)
            stack(.cart) { CartView() }
                .tabItem { Label("Cart", systemImage: "cart") }
                .badge(store.cartCount)
                .tag(ShopTab.cart)
            stack(.account) { AccountView() }
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
                .tag(ShopTab.account)
            #if DEBUG
            stack(.diagnostics) { DiagnosticsView() }
                .tabItem { Label("Diagnostics", systemImage: "info.circle") }
                .tag(ShopTab.diagnostics)
            #endif
        }
        .tint(ShopTheme.primary)
        .environmentObject(router)
    }

    private func stack<Content: View>(_ tab: ShopTab, @ViewBuilder content: () -> Content) -> some View {
        NavigationStack(path: router.path(for: tab)) {
            content()
                .navigationDestination(for: ShopRoute.self) { route in
                    switch route {
                    case .product(let id): ProductDetailView(productID: id)
                    case .checkout: CheckoutView()
                    case .orders: OrdersView()
                    case .order(let id): OrderDetailView(orderID: id)
                    }
                }
        }
    }
}
