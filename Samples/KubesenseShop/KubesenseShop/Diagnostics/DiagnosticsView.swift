/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Kubesense addition to the fork of dd-sdk-ios, see docs/UPSTREAM_SYNC.md.
 */

import KubesenseRUM
import SwiftUI

struct DiagnosticsView: View {
    @State private var group: DiagnosticGroup?
    @State private var result: String?
    @State private var pendingDestructive: DiagnosticScenario?
    @State private var showingLegacy = false

    private var visible: [DiagnosticScenario] {
        KubesenseDiagnostics.scenarios.filter { group == nil || $0.group == group }
    }

    var body: some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        chip("All", selected: group == nil) { group = nil }
                        ForEach(DiagnosticGroup.allCases) { item in
                            chip(item.rawValue, selected: group == item) { group = item }
                        }
                    }
                }
                Button("Open UIKit views & WebView tests") { showingLegacy = true }
            } header: {
                Text("Generate one deterministic signal at a time")
            }
            ForEach(visible) { scenario in
                HStack(alignment: .top, spacing: 12) {
                    Text(scenario.destructive ? "!" : "✓")
                        .font(.headline)
                        .frame(width: 32, height: 32)
                        .background(scenario.destructive ? Color.red.opacity(0.18) : ShopTheme.primaryContainer, in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(scenario.title).font(.subheadline.bold())
                        Text(scenario.description).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Run") {
                        if scenario.destructive {
                            pendingDestructive = scenario
                        } else {
                            Task { result = await KubesenseDiagnostics.run(scenario.id) }
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .navigationTitle("Observability lab")
        .overlay(alignment: .bottom) {
            if let result {
                Text(result)
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(.black.opacity(0.85), in: Capsule())
                    .padding(.bottom, 12)
                    .task(id: result) {
                        try? await Task.sleep(nanoseconds: 2_500_000_000)
                        self.result = nil
                    }
            }
        }
        .alert(
            "This will interrupt the app",
            isPresented: Binding(get: { pendingDestructive != nil }, set: { if !$0 { pendingDestructive = nil } }),
            presenting: pendingDestructive
        ) { scenario in
            Button("Run \(scenario.title)", role: .destructive) {
                Task { _ = await KubesenseDiagnostics.run(scenario.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { scenario in
            Text("\(scenario.description) Reopen the app afterward to verify the captured report.")
        }
        .sheet(isPresented: $showingLegacy) {
            LegacyShowcaseScreen().ignoresSafeArea()
        }
        .trackRUMView(name: "diagnostics")
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(selected ? ShopTheme.primaryContainer : ShopTheme.surfaceVariant.opacity(0.5), in: Capsule())
            .buttonStyle(.plain)
    }
}
