/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Kubesense addition to the fork of dd-sdk-ios, see docs/UPSTREAM_SYNC.md.
 */

import Foundation
import Testing
import KubesenseInternal
@testable import KubesenseCore

/// Records requests and answers them with a canned response.
final class RecordingHTTPClient: HTTPClient, @unchecked Sendable {
    let lock = NSLock()
    var requests: [URLRequest] = []
    let statusCode: Int
    let body: Data?
    init(statusCode: Int = 200, body: Data?) { self.statusCode = statusCode; self.body = body }
    func send(request: URLRequest, delegate: URLSessionTaskDelegate?, completion: @escaping (Result<(HTTPURLResponse, Data?), Error>) -> Void) {
        lock.lock(); requests.append(request); lock.unlock()
        let response = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        DispatchQueue.global().async { completion(.success((response, self.body))) }
    }
    var sent: [URLRequest] { lock.lock(); defer { lock.unlock() }; return requests }
}

func temporaryDirectory() throws -> Directory {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("ks-rc-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return Directory(url: url)
}

func waitUntil(_ condition: () -> Bool) {
    let deadline = Date().addingTimeInterval(5)
    while !condition() && Date() < deadline { Thread.sleep(forTimeInterval: 0.02) }
}

@Suite(.serialized) struct RemoteConfigurationRuntimeTests {
    let document = Data(#"{"version":1,"features":{"logs":false},"core":{"batchSize":"SMALL","uploadFrequency":"RARE"},"rum":{"sessionSampleRate":42}}"#.utf8)

    @Test func providerFetchesAuthenticatesCachesAndReloads() throws {
        let directory = try temporaryDirectory()
        let client = RecordingHTTPClient(body: document)
        let provider = RemoteConfigurationProvider(
            endpoint: URL(string: "https://collector.example.com")!, clientToken: "client-token",
            directory: directory, httpClient: client, notificationCenterProvider: .isolated, refreshPeriod: 0
        )
        var delivered: [RemoteConfigDocument] = []
        provider.start { delivered.append($0) }
        waitUntil { directory.hasFile(named: "kubesense-sdk-config.json") }

        let request = try #require(client.sent.first)
        #expect(request.httpMethod == "GET")
        #expect(request.url?.absoluteString == "https://collector.example.com/rum/api/v1/sdk-config")
        #expect(request.value(forHTTPHeaderField: "KUBESENSE-API-KEY") == "client-token")
        #expect(URLRequestBuilder.isMarkedInternal(request))
        #expect(delivered.isEmpty, "a fetched document applies at the next launch")

        let nextLaunch = RemoteConfigurationProvider(
            endpoint: URL(string: "https://collector.example.com")!, clientToken: "client-token",
            directory: directory, httpClient: client, notificationCenterProvider: .isolated, refreshPeriod: 0
        )
        let cached = nextLaunch.readCachedDocument()
        #expect(cached.bool("features", "logs") == false)
        #expect(cached.sampleRate("rum", "sessionSampleRate") == 42)
        provider.stop()
    }

    @Test func anUnusableResponseKeepsTheCachedDocument() throws {
        let directory = try temporaryDirectory()
        let good = RemoteConfigurationProvider(
            endpoint: URL(string: "https://collector.example.com")!, clientToken: "t",
            directory: directory, httpClient: RecordingHTTPClient(body: document), notificationCenterProvider: .isolated, refreshPeriod: 0
        )
        good.start { _ in }
        waitUntil { directory.hasFile(named: "kubesense-sdk-config.json") }
        good.stop()

        for (status, body) in [(200, Data("[]".utf8)), (200, Data("not json".utf8)), (404, Data(#"{"error":"x"}"#.utf8))] {
            let client = RecordingHTTPClient(statusCode: status, body: body)
            let bad = RemoteConfigurationProvider(
                endpoint: URL(string: "https://collector.example.com")!, clientToken: "t",
                directory: directory, httpClient: client, notificationCenterProvider: .isolated, refreshPeriod: 0
            )
            bad.start { _ in }
            waitUntil { !client.sent.isEmpty }
            Thread.sleep(forTimeInterval: 0.2)
            #expect(bad.readCachedDocument().sampleRate("rum", "sessionSampleRate") == 42)
            bad.stop()
        }
    }

    @MainActor @Test func initializationAppliesTheCachedDocument() throws {
        // Given — a document cached by a previous launch
        let persistent = try temporaryDirectory()
        let caches = try temporaryDirectory()
        let seed = RemoteConfigurationProvider(
            endpoint: KubesenseSite.prod.endpoint, clientToken: "abc-123",
            directory: try CoreDirectory(in: persistent, instanceName: "rc-runtime", site: .prod).coreDirectory,
            httpClient: RecordingHTTPClient(body: document), notificationCenterProvider: .isolated, refreshPeriod: 0
        )
        seed.start { _ in }
        waitUntil { seed.readCachedDocument().isEmpty == false }
        seed.stop()

        var configuration = Kubesense.Configuration(clientToken: "abc-123", env: "tests", kubesenseRumEndpoint: "collector.example.com")
        configuration.persistentDirectory = { persistent }
        configuration.systemDirectory = { caches }
        let client = RecordingHTTPClient(statusCode: 304, body: nil)
        configuration.httpClientFactory = { _ in client }

        // When
        let core = try KubesenseCore(configuration: configuration, trackingConsent: .granted, instanceName: "rc-runtime")
        defer { core.stop() }

        // Then — the core settings, the context and the feature switches follow the document
        #expect(core.remoteConfigDocument.bool("features", "logs") == false)
        #expect(core.performance == PerformancePreset(batchSize: .small, uploadFrequency: .rare, bundleType: BundleType(bundle: .main), batchProcessingLevel: .medium))
        #expect(core.contextProvider.read().intakeEndpoint.absoluteString == "https://collector.example.com")
        #expect(core.isFeatureDisabledRemotely(featureKey: "logs", featureName: "Logs"))
        #expect(!core.isFeatureDisabledRemotely(featureKey: "rum", featureName: "RUM"))
        waitUntil { !client.sent.isEmpty }
        #expect(client.sent.first?.url?.absoluteString == "https://collector.example.com/rum/api/v1/sdk-config")
    }
}

/// Notification centers no other test posts to.
private extension NotificationCenterProvider {
    static var isolated: NotificationCenterProvider {
        #if os(macOS)
        .init(applicationCenter: NotificationCenter(), workspaceCenter: NotificationCenter())
        #else
        .init(applicationCenter: NotificationCenter())
        #endif
    }
}
