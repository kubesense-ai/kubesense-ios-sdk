/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Kubesense addition to the fork of dd-sdk-ios, see docs/UPSTREAM_SYNC.md.
 */

import Foundation

/// Persists the cart and the signed-in user between launches. Signing out keeps the cart.
struct ShopSessionStore {
    private let defaults: UserDefaults
    private let tokenKey = "kubesense_shop.auth_token"
    private let userKey = "kubesense_shop.auth_user"
    private let cartKey = "kubesense_shop.cart"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var token: String? { defaults.string(forKey: tokenKey) }

    var user: AuthUser? {
        defaults.data(forKey: userKey).flatMap { try? JSONDecoder().decode(AuthUser.self, from: $0) }
    }

    var cart: [Int: Int] {
        guard let data = defaults.data(forKey: cartKey),
              let stored = try? JSONDecoder().decode([String: Int].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: stored.compactMap { key, value in Int(key).map { ($0, value) } })
    }

    func saveAuthentication(_ session: AuthSession) {
        defaults.set(session.token, forKey: tokenKey)
        defaults.set(try? JSONEncoder().encode(session.user), forKey: userKey)
    }

    func clearAuthentication() {
        defaults.removeObject(forKey: tokenKey)
        defaults.removeObject(forKey: userKey)
    }

    func saveCart(_ cart: [Int: Int]) {
        let stored = Dictionary(uniqueKeysWithValues: cart.map { (String($0.key), $0.value) })
        defaults.set(try? JSONEncoder().encode(stored), forKey: cartKey)
    }
}
