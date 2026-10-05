/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Kubesense addition to the fork of dd-sdk-ios, see docs/UPSTREAM_SYNC.md.
 */

import KubesenseRUM
import SwiftUI

struct CartView: View {
    @EnvironmentObject private var store: ShopStore
    @EnvironmentObject private var router: ShopRouter

    var body: some View {
        let lines = store.cartLines
        List {
            if let message = store.orderMessage {
                Text(message).foregroundStyle(.red)
            }
            if lines.isEmpty {
                EmptyStateView(title: "Your cart is empty", message: "Add something from the Shop to continue.")
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(lines, id: \.product.id) { line in
                        HStack(spacing: 12) {
                            SquareProductArt(product: line.product, size: 72)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(line.product.title).font(.subheadline.bold()).lineLimit(2)
                                Text(ShopFormat.price(line.product.price)).font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button { store.removeFromCart(line.product.id) } label: { Image(systemName: "minus.circle") }
                                .accessibilityLabel("Remove one")
                            Text("\(line.quantity)").monospacedDigit()
                            Button { store.addToCart(line.product.id) } label: { Image(systemName: "plus.circle") }
                                .accessibilityLabel("Add one")
                        }
                        .buttonStyle(.borderless)
                        .font(.title3)
                    }
                }
                Section {
                    HStack {
                        Text("Total").font(.headline)
                        Spacer()
                        Text(ShopFormat.price(store.cartTotal)).font(.headline)
                    }
                    Button("Continue to checkout") { router.continueToCheckout(signedIn: store.user != nil) }
                        .buttonStyle(PrimaryButtonStyle())
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
            }
        }
        .navigationTitle("Your cart")
        .trackRUMView(name: "cart")
    }
}

struct CheckoutView: View {
    @EnvironmentObject private var store: ShopStore
    @EnvironmentObject private var router: ShopRouter
    @State private var address = "221B Market Street, Bengaluru"
    @State private var cardNumber = "4242 4242 4242 4242"

    private var canPlaceOrder: Bool {
        !address.trimmingCharacters(in: .whitespaces).isEmpty
            && cardNumber.filter(\.isNumber).count >= 12
            && !store.cartLines.isEmpty
            && !store.checkoutInProgress
    }

    var body: some View {
        Form {
            Section("Delivery") {
                TextField("Delivery address", text: $address, axis: .vertical).lineLimit(2...4)
            }
            Section("Payment") {
                TextField("Test card number", text: $cardNumber)
                    .keyboardType(.numberPad)
                    .onChange(of: cardNumber) { value in
                        if value.count > 19 { cardNumber = String(value.prefix(19)) }
                    }
            }
            Section("Order summary") {
                ForEach(store.cartLines, id: \.product.id) { line in
                    HStack(spacing: 12) {
                        SquareProductArt(product: line.product, size: 58, cornerRadius: 12)
                        VStack(alignment: .leading) {
                            Text(line.product.title).font(.subheadline.bold()).lineLimit(1)
                            Text("Quantity \(line.quantity)").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(ShopFormat.price(line.product.price * Double(line.quantity)))
                    }
                }
                HStack {
                    Text("Total").font(.headline)
                    Spacer()
                    Text(ShopFormat.price(store.cartTotal)).font(.headline)
                }
            }
            if let message = store.orderMessage {
                Text(message).foregroundStyle(.red)
            }
            Button(store.checkoutInProgress ? "Placing order…" : "Place order") {
                RUMMonitor.shared().addTiming(name: "checkout.confirmed")
                Task {
                    await store.checkout {
                        router.showOrdersAfterCheckout()
                        Task { await store.loadOrders() }
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canPlaceOrder)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
        .navigationTitle("Checkout")
        .trackRUMView(name: "checkout")
    }
}

struct OrdersView: View {
    @EnvironmentObject private var store: ShopStore
    @EnvironmentObject private var router: ShopRouter

    var body: some View {
        List {
            if store.ordersLoading && store.orders.isEmpty {
                ProgressView().frame(maxWidth: .infinity)
            } else if store.orders.isEmpty {
                EmptyStateView(title: store.orderMessage ?? "No orders yet", message: "Orders you place appear here.")
                    .listRowBackground(Color.clear)
            } else {
                ForEach(store.orders) { order in
                    Button { router.push(.order(order.id)) } label: { OrderSummaryRow(order: order) }
                        .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Order history")
        .toolbar {
            Button("Refresh") { Task { await store.loadOrders() } }
        }
        .refreshable { await store.loadOrders() }
        .trackRUMView(name: "orders")
    }
}

private struct OrderSummaryRow: View {
    let order: Order

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Order #\(order.id)").font(.subheadline.bold()).lineLimit(1)
                Spacer()
                Text(order.status.uppercased()).font(.caption.bold()).foregroundStyle(ShopTheme.secondary)
            }
            Text(order.createdAt).font(.caption).foregroundStyle(.secondary)
            Text("\(order.items.reduce(0) { $0 + $1.quantity }) items · \(ShopFormat.price(order.total))").font(.footnote)
            ForEach(order.items.prefix(3), id: \.productId) { item in
                Text("\(item.quantity)× \(item.title)").font(.caption).foregroundStyle(.secondary)
            }
            if order.items.count > 3 {
                Text("+\(order.items.count - 3) more").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct OrderDetailView: View {
    @EnvironmentObject private var store: ShopStore
    let orderID: String

    var body: some View {
        List {
            if let order = store.orders.first(where: { $0.id == orderID }) {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Order #\(order.id)").font(.headline)
                        Text(order.status.uppercased()).font(.caption.bold()).foregroundStyle(ShopTheme.secondary)
                        Text(order.createdAt).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section {
                    ForEach(order.items, id: \.productId) { item in
                        let product = store.products.first(where: { $0.id == item.productId })
                            ?? Product(id: item.productId, title: item.title, description: "", price: item.price, category: "Purchased item", rating: 0)
                        HStack(spacing: 12) {
                            SquareProductArt(product: product, size: 88, cornerRadius: 16)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title).font(.subheadline.bold()).lineLimit(2)
                                Text("Quantity: \(item.quantity)").font(.caption)
                                Text("\(ShopFormat.price(item.price)) each").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(ShopFormat.price(item.price * Double(item.quantity))).font(.subheadline.bold())
                        }
                    }
                }
                HStack {
                    Text("Order total").font(.headline)
                    Spacer()
                    Text(ShopFormat.price(order.total)).font(.headline)
                }
            } else {
                EmptyStateView(title: "Order unavailable", message: "Refresh your order history.")
            }
        }
        .navigationTitle("Order details")
        .trackRUMView(name: "order/{id}", attributes: ["view.arguments.id": orderID])
    }
}
