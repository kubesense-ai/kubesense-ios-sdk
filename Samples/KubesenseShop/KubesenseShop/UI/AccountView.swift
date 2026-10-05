/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Kubesense addition to the fork of dd-sdk-ios, see docs/UPSTREAM_SYNC.md.
 */

import KubesenseRUM
import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var store: ShopStore
    @EnvironmentObject private var router: ShopRouter
    @State private var registering = false
    @State private var name = ""
    @State private var email = "admin@kubesense.ai"
    @State private var password = "Kube@1234$"
    @State private var sessionID = "Tap to resolve asynchronously"

    var body: some View {
        List {
            if store.user == nil, router.returnRouteAfterAuthentication != nil {
                StatusCard(title: "Sign in required", message: "Sign in or register to continue, then you’ll return to Checkout.")
                    .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            }
            Section {
                if KubesenseSetup.sdkEnabled {
                    StatusCard(title: "SDK connected", message: "Events use \(store.config.flavor) configuration.")
                } else {
                    StatusCard(title: "Preview mode", message: "Add SDK credentials to Config/local.json.")
                }
            }
            .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)

            if let user = store.user {
                Section("Signed in") {
                    Text(user.name).font(.headline)
                    Text(user.email).foregroundStyle(ShopTheme.primary)
                    Text("User ID: \(user.id)").font(.caption).foregroundStyle(.secondary)
                    Text("This ID and email are attached to subsequent SDK events.").font(.caption)
                    Button("View order history") {
                        Task { await store.loadOrders() }
                        router.push(.orders)
                    }
                    Button("Sign out", role: .destructive) { store.logout() }
                }
            } else {
                Section {
                    Picker("Mode", selection: $registering) {
                        Text("Login").tag(false)
                        Text("Register").tag(true)
                    }
                    .pickerStyle(.segmented)
                    if registering {
                        TextField("Full name", text: $name).textContentType(.name)
                    }
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                    Button(store.authInProgress ? "Please wait…" : (registering ? "Create account" : "Sign in")) {
                        Task {
                            if registering {
                                await store.register(name: name, email: email, password: password) { router.resumeAfterAuthentication() }
                            } else {
                                await store.login(email: email, password: password) { router.resumeAfterAuthentication() }
                            }
                        }
                    }
                    .disabled(store.authInProgress)
                } footer: {
                    Text("Create an account first; users are persisted by the local sample API.")
                }
            }

            if let message = store.authMessage {
                Text(message).font(.footnote)
            }

            Section("RUM session") {
                Button("Get current session") {
                    RUMMonitor.shared().currentSessionID { id in
                        Task { @MainActor in sessionID = id ?? "No sampled session" }
                    }
                }
                Text(sessionID).font(.caption.monospaced()).textSelection(.enabled)
            }
        }
        .navigationTitle("Account & privacy")
        .trackRUMView(name: "account")
    }
}
