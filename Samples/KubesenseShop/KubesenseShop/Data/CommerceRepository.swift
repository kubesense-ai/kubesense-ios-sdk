/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Kubesense addition to the fork of dd-sdk-ios, see docs/UPSTREAM_SYNC.md.
 */

import Foundation

/// Session delegate registered with `URLSessionInstrumentation.enableDurationBreakdown`, so RUM
/// resources from this session carry DNS, connect, TLS and transfer timings.
final class ShopURLSessionDelegate: NSObject, URLSessionDataDelegate {}

/// Talks to the Kubesense Shop sample API, falling back to the offline catalog when it is not
/// configured or not reachable. Every request goes through an instrumented URLSession, so it is
/// reported as a RUM resource and traced on first-party hosts.
final class CommerceRepository {
    static let pageSize = 20

    private let baseURL: URL?
    private let session: URLSession

    init(baseURL: String, session: URLSession? = nil) {
        let trimmed = baseURL.trimmingCharacters(in: .whitespaces)
        self.baseURL = trimmed.isEmpty ? nil : URL(string: trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed)
        self.session = session ?? URLSession(configuration: .default, delegate: ShopURLSessionDelegate(), delegateQueue: nil)
    }

    // MARK: - Products

    func loadProducts(page: Int) async -> ProductCatalog {
        guard let baseURL else {
            return FallbackCatalog.page(page, limit: Self.pageSize, message: "No sample API configured")
        }
        do {
            var components = URLComponents(url: baseURL.appendingPathComponent("products"), resolvingAgainstBaseURL: false)!
            components.queryItems = [URLQueryItem(name: "page", value: "\(page)"), URLQueryItem(name: "limit", value: "\(Self.pageSize)")]
            let (data, response) = try await session.data(from: components.url!)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(status) else { throw ShopError("HTTP \(status)") }
            let envelope = try JSONDecoder().decode(ProductEnvelope.self, from: data)
            let products = (envelope.products ?? []).compactMap(\.product)
            if products.isEmpty && page == 1 { throw ShopError("The API returned an empty catalog") }
            return ProductCatalog(
                products: products,
                origin: .live,
                message: nil,
                page: envelope.page ?? page,
                total: envelope.total ?? products.count,
                hasMore: envelope.hasMore ?? false
            )
        } catch {
            return FallbackCatalog.page(page, limit: Self.pageSize, message: "Live catalog unavailable: \(error.localizedDescription)")
        }
    }

    // MARK: - Authentication

    func register(name: String, email: String, password: String) async -> Result<AuthSession, ShopError> {
        await authenticate(path: "auth/register", body: ["name": name, "email": email, "password": password])
    }

    func login(email: String, password: String) async -> Result<AuthSession, ShopError> {
        await authenticate(path: "auth/login", body: ["email": email, "password": password])
    }

    private struct AuthEnvelope: Decodable {
        let user: AuthUser?
        let token: String?
        let error: String?
    }

    private func authenticate(path: String, body: [String: String]) async -> Result<AuthSession, ShopError> {
        guard let baseURL else { return .failure(ShopError("No sample API configured")) }
        do {
            let (data, status) = try await send(baseURL.appendingPathComponent(path), method: "POST", body: body)
            let envelope = try? JSONDecoder().decode(AuthEnvelope.self, from: data)
            guard (200..<300).contains(status) else { return .failure(ShopError(envelope?.error ?? "HTTP \(status)")) }
            guard let user = envelope?.user, let token = envelope?.token else {
                return .failure(ShopError("The API returned no user"))
            }
            return .success(AuthSession(user: user, token: token))
        } catch {
            return .failure(ShopError("Network request failed: \(error.localizedDescription)"))
        }
    }

    // MARK: - Orders

    private struct OrdersEnvelope: Decodable {
        let order: Order?
        let orders: [Order]?
        let error: String?
    }

    func createOrder(token: String, cart: [Int: Int], products: [Product]) async -> Result<[Order], ShopError> {
        let items = cart.compactMap { id, quantity -> OrderItem? in
            guard let product = products.first(where: { $0.id == id }) else { return nil }
            return OrderItem(productId: id, title: product.title, quantity: quantity, price: product.price)
        }
        return await orders(method: "POST", token: token, body: ["items": items], attempts: 1)
    }

    /// Retried once on a network failure (not on an HTTP error), like the Android sample.
    func loadOrders(token: String) async -> Result<[Order], ShopError> {
        await orders(method: "GET", token: token, body: nil as [String: [OrderItem]]?, attempts: 2)
    }

    private func orders<Body: Encodable>(method: String, token: String, body: Body?, attempts: Int) async -> Result<[Order], ShopError> {
        guard let baseURL else { return .failure(ShopError("No sample API configured")) }
        var lastError: Error?
        for attempt in 1...attempts {
            do {
                let (data, status) = try await send(baseURL.appendingPathComponent("orders"), method: method, body: body, token: token)
                let envelope = try? JSONDecoder().decode(OrdersEnvelope.self, from: data)
                guard (200..<300).contains(status) else { return .failure(ShopError(envelope?.error ?? "HTTP \(status)")) }
                if let order = envelope?.order { return .success([order]) }
                return .success(envelope?.orders ?? [])
            } catch {
                lastError = error
                if attempt < attempts { try? await Task.sleep(nanoseconds: 250_000_000) }
            }
        }
        return .failure(ShopError("Network request failed: \(lastError?.localizedDescription ?? "unknown")"))
    }

    // MARK: - Transport

    private func send<Body: Encodable>(_ url: URL, method: String, body: Body?, token: String? = nil) async throws -> (Data, Int) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body { request.httpBody = try JSONEncoder().encode(body) }
        let (data, response) = try await session.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }
}

struct ShopError: Error, LocalizedError, Equatable {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
