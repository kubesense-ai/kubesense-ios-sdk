/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import XCTest
import TestUtilities

@testable import KubesenseInternal
@testable import KubesenseLogs
@testable import KubesenseTrace
@testable import KubesenseCore

// MARK: KubesenseTests

class KubesenseTests: XCTestCase {
    private var printFunction: PrintFunctionSpy! // swiftlint:disable:this implicitly_unwrapped_optional
    // Remote configuration is off so that initializing the SDK in these tests never fetches from the network.
    private var defaultConfig = Kubesense.Configuration(clientToken: "abc-123", env: "tests", remoteConfigurationEnabled: false)

    override func setUp() {
        super.setUp()

        XCTAssertFalse(Kubesense.isInitialized())
        printFunction = PrintFunctionSpy()
        consolePrint = printFunction.print
    }

    override func tearDown() {
        consolePrint = { message, _ in print(message) }
        printFunction = nil
        XCTAssertFalse(Kubesense.isInitialized())
        super.tearDown()
    }

    // MARK: - Initializing with different configurations

    func testDefaultConfiguration() throws {
        var configuration = defaultConfig

        configuration.bundle = .mockWith(
            bundleIdentifier: "test",
            CFBundleShortVersionString: "1.0.0",
            CFBundleExecutable: "Test"
        )

        XCTAssertEqual(configuration.batchSize, .medium)
        XCTAssertEqual(configuration.uploadFrequency, .average)
        XCTAssertEqual(configuration.additionalConfiguration.count, 0)
        XCTAssertNil(configuration.encryption)
        XCTAssertTrue(configuration.serverDateProvider is KubesenseNTPDateProvider)

        Kubesense.initialize(
            with: configuration,
            trackingConsent: .granted
        )
        defer { Kubesense.flushAndDeinitialize() }

        let core = try XCTUnwrap(CoreRegistry.default as? KubesenseCore)
        let urlSessionClient = try XCTUnwrap(core.httpClient as? URLSessionClient)
        XCTAssertTrue(core.dateProvider is SystemDateProvider)
        XCTAssertNil(urlSessionClient.session.configuration.connectionProxyDictionary)
        XCTAssertNil(core.encryption)

        let context = core.contextProvider.read()
        XCTAssertEqual(context.clientToken, "abc-123")
        XCTAssertEqual(context.env, "tests")
        XCTAssertEqual(context.site, .prod)
        XCTAssertEqual(context.service, "test")
        XCTAssertEqual(context.version, "1.0.0")
        XCTAssertEqual(context.sdkVersion, __sdkVersion)
        XCTAssertEqual(context.applicationName, "Test")
        XCTAssertNil(context.variant)
        XCTAssertEqual(context.source, "ios")
        XCTAssertEqual(context.applicationBundleIdentifier, "test")
        XCTAssertEqual(context.trackingConsent, .granted)
    }

    func testAdvancedConfiguration() throws {
        var configuration = defaultConfig

        configuration.service = "service-name"
        configuration.site = .staging
        configuration.batchSize = .small
        configuration.uploadFrequency = .frequent
        #if !os(watchOS)
        configuration.proxyConfiguration = [
            kCFNetworkProxiesHTTPEnable: true,
            kCFNetworkProxiesHTTPPort: 123,
            kCFNetworkProxiesHTTPProxy: "www.example.com",
            kCFProxyUsernameKey: "proxyuser",
            kCFProxyPasswordKey: "proxypass",
        ]
        #endif
        configuration.bundle = .mockWith(
            bundleIdentifier: "test",
            CFBundleShortVersionString: "1.0.0",
            CFBundleExecutable: "Test"
        )
        configuration.encryption = DataEncryptionMock()
        configuration.serverDateProvider = ServerDateProviderMock()
        configuration._internal_mutation {
            $0.additionalConfiguration = [
                CrossPlatformAttributes.ksource: "cp-source",
                CrossPlatformAttributes.variant: "cp-variant",
                CrossPlatformAttributes.sdkVersion: "cp-version"
            ]
        }

        XCTAssertEqual(configuration.batchSize, .small)
        XCTAssertEqual(configuration.uploadFrequency, .frequent)
        XCTAssertTrue(configuration.encryption is DataEncryptionMock)
        XCTAssertTrue(configuration.serverDateProvider is ServerDateProviderMock)

        Kubesense.initialize(
            with: configuration,
            trackingConsent: .pending
        )
        defer { Kubesense.flushAndDeinitialize() }

        let core = try XCTUnwrap(CoreRegistry.default as? KubesenseCore)
        XCTAssertTrue(core.dateProvider is SystemDateProvider)
        XCTAssertTrue(core.encryption is DataEncryptionMock)

        #if !os(watchOS)
        let urlSessionClient = try XCTUnwrap(core.httpClient as? URLSessionClient)
        let connectionProxyDictionary = try XCTUnwrap(urlSessionClient.session.configuration.connectionProxyDictionary)
        XCTAssertEqual(connectionProxyDictionary[kCFNetworkProxiesHTTPEnable] as? Bool, true)
        XCTAssertEqual(connectionProxyDictionary[kCFNetworkProxiesHTTPPort] as? Int, 123)
        XCTAssertEqual(connectionProxyDictionary[kCFNetworkProxiesHTTPProxy] as? String, "www.example.com")
        XCTAssertEqual(connectionProxyDictionary[kCFProxyUsernameKey] as? String, "proxyuser")
        XCTAssertEqual(connectionProxyDictionary[kCFProxyPasswordKey] as? String, "proxypass")
        #endif

        let context = core.contextProvider.read()
        XCTAssertEqual(context.clientToken, "abc-123")
        XCTAssertEqual(context.env, "tests")
        XCTAssertEqual(context.site, .staging)
        XCTAssertEqual(context.service, "service-name")
        XCTAssertEqual(context.version, "1.0.0")
        XCTAssertEqual(context.sdkVersion, "cp-version")
        XCTAssertEqual(context.applicationName, "Test")
        XCTAssertEqual(context.variant, "cp-variant")
        XCTAssertEqual(context.source, "cp-source")
        XCTAssertEqual(context.applicationBundleIdentifier, "test")
        XCTAssertEqual(context.trackingConsent, .pending)
    }

    func testGivenDefaultConfiguration_itCanBeInitialized() {
        Kubesense.initialize(
            with: defaultConfig,
            trackingConsent: .mockRandom()
        )
        XCTAssertTrue(Kubesense.isInitialized())
        Kubesense.flushAndDeinitialize()
    }

    func testGivenInvalidConfiguration_itPrintsError() {
        let invalidConfiguration = Kubesense.Configuration(clientToken: "", env: "tests")

        Kubesense.initialize(
            with: invalidConfiguration,
            trackingConsent: .mockRandom()
        )

        XCTAssertEqual(
            printFunction.printedMessage,
            "🔥 Kubesense SDK usage error: `clientToken` cannot be empty."
        )
        XCTAssertFalse(Kubesense.isInitialized())
    }

    func testGivenValidConfiguration_whenInitializedMoreThanOnce_itPrintsError() {
        Kubesense.initialize(
            with: defaultConfig,
            trackingConsent: .mockRandom()
        )

        Kubesense.initialize(
            with: defaultConfig,
            trackingConsent: .mockRandom()
        )

        XCTAssertEqual(
            printFunction.printedMessage,
            "🔥 Kubesense SDK usage error: The 'main' instance of SDK is already initialized."
        )

        Kubesense.flushAndDeinitialize()
    }

    // MARK: - Public APIs

    func testTrackingConsent() {
        let initialConsent: TrackingConsent = .mockRandom()
        let nextConsent: TrackingConsent = .mockRandom()

        Kubesense.initialize(
            with: defaultConfig,
            trackingConsent: initialConsent
        )

        let core = CoreRegistry.default as? KubesenseCore
        XCTAssertEqual(core?.consentPublisher.consent, initialConsent)

        Kubesense.set(trackingConsent: nextConsent)

        XCTAssertEqual(core?.consentPublisher.consent, nextConsent)

        Kubesense.flushAndDeinitialize()
    }

    func testUserInfo() {
        Kubesense.initialize(
            with: defaultConfig,
            trackingConsent: .mockRandom()
        )

        let core = CoreRegistry.default as? KubesenseCore

        XCTAssertNil(core?.userInfoPublisher.current.id)
        XCTAssertNil(core?.userInfoPublisher.current.email)
        XCTAssertNil(core?.userInfoPublisher.current.name)
        XCTAssertEqual(core?.userInfoPublisher.current.extraInfo as? [String: Int], [:])

        Kubesense.setUserInfo(
            id: "foo",
            name: "bar",
            email: "foo@bar.com",
            extraInfo: ["abc": 123]
        )
        core?.set(anonymousId: "anonymous-id")

        XCTAssertEqual(core?.userInfoPublisher.current.anonymousId, "anonymous-id")
        XCTAssertEqual(core?.userInfoPublisher.current.id, "foo")
        XCTAssertEqual(core?.userInfoPublisher.current.name, "bar")
        XCTAssertEqual(core?.userInfoPublisher.current.email, "foo@bar.com")
        XCTAssertEqual(core?.userInfoPublisher.current.extraInfo as? [String: Int], ["abc": 123])

        Kubesense.clearUserInfo()

        XCTAssertEqual(core?.userInfoPublisher.current.anonymousId, "anonymous-id")
        XCTAssertNil(core?.userInfoPublisher.current.id)
        XCTAssertNil(core?.userInfoPublisher.current.email)
        XCTAssertNil(core?.userInfoPublisher.current.name)
        XCTAssertEqual(core?.userInfoPublisher.current.extraInfo as? [String: Int], [:])

        Kubesense.flushAndDeinitialize()
    }

    func testAddUserProperties_mergesProperties() {
        Kubesense.initialize(
            with: defaultConfig,
            trackingConsent: .mockRandom()
        )

        let core = CoreRegistry.default as? KubesenseCore

        Kubesense.setUserInfo(
            id: "foo",
            name: "bar",
            email: "foo@bar.com",
            extraInfo: ["abc": 123]
        )

        Kubesense.addUserExtraInfo(["second": 667])

        XCTAssertEqual(core?.userInfoPublisher.current.id, "foo")
        XCTAssertEqual(core?.userInfoPublisher.current.name, "bar")
        XCTAssertEqual(core?.userInfoPublisher.current.email, "foo@bar.com")
        XCTAssertEqual(
            core?.userInfoPublisher.current.extraInfo as? [String: Int],
            ["abc": 123, "second": 667]
        )

        Kubesense.flushAndDeinitialize()
    }

    func testAddUserProperties_removesProperties() {
        Kubesense.initialize(
            with: defaultConfig,
            trackingConsent: .mockRandom()
        )

        let core = CoreRegistry.default as? KubesenseCore

        Kubesense.setUserInfo(
            id: "foo",
            name: "bar",
            email: "foo@bar.com",
            extraInfo: ["abc": 123]
        )

        Kubesense.addUserExtraInfo(["abc": nil, "second": 667])

        XCTAssertEqual(core?.userInfoPublisher.current.id, "foo")
        XCTAssertEqual(core?.userInfoPublisher.current.name, "bar")
        XCTAssertEqual(core?.userInfoPublisher.current.email, "foo@bar.com")
        XCTAssertEqual(core?.userInfoPublisher.current.extraInfo as? [String: Int], ["second": 667])

        Kubesense.flushAndDeinitialize()
    }

    func testAddUserProperties_overwritesProperties() {
        Kubesense.initialize(
            with: defaultConfig,
            trackingConsent: .mockRandom()
        )

        let core = CoreRegistry.default as? KubesenseCore

        Kubesense.setUserInfo(
            id: "foo",
            name: "bar",
            email: "foo@bar.com",
            extraInfo: ["abc": 123]
        )

        Kubesense.addUserExtraInfo(["abc": 444])

        XCTAssertEqual(core?.userInfoPublisher.current.id, "foo")
        XCTAssertEqual(core?.userInfoPublisher.current.name, "bar")
        XCTAssertEqual(core?.userInfoPublisher.current.email, "foo@bar.com")
        XCTAssertEqual(core?.userInfoPublisher.current.extraInfo as? [String: Int], ["abc": 444])

        Kubesense.flushAndDeinitialize()
    }

    func testAccountInfo() {
        Kubesense.initialize(
            with: defaultConfig,
            trackingConsent: .mockRandom()
        )

        let core = CoreRegistry.default as? KubesenseCore

        XCTAssertNil(core?.accountInfoPublisher.current)

        Kubesense.setAccountInfo(
            id: "foo",
            name: "bar",
            extraInfo: ["abc": 123]
        )

        XCTAssertEqual(core?.accountInfoPublisher.current?.id, "foo")
        XCTAssertEqual(core?.accountInfoPublisher.current?.name, "bar")
        XCTAssertEqual(core?.accountInfoPublisher.current?.extraInfo as? [String: Int], ["abc": 123])

        Kubesense.flushAndDeinitialize()
    }

    func testAddAccountProperties_mergesProperties() {
        Kubesense.initialize(
            with: defaultConfig,
            trackingConsent: .mockRandom()
        )

        let core = CoreRegistry.default as? KubesenseCore

        Kubesense.setAccountInfo(
            id: "foo",
            name: "bar",
            extraInfo: ["abc": 123]
        )

        Kubesense.addAccountExtraInfo(["second": 667])

        XCTAssertEqual(core?.accountInfoPublisher.current?.id, "foo")
        XCTAssertEqual(core?.accountInfoPublisher.current?.name, "bar")
        XCTAssertEqual(
            core?.accountInfoPublisher.current?.extraInfo as? [String: Int],
            ["abc": 123, "second": 667]
        )

        Kubesense.flushAndDeinitialize()
    }

    func testAddAccountProperties_removesProperties() {
        Kubesense.initialize(
            with: defaultConfig,
            trackingConsent: .mockRandom()
        )

        let core = CoreRegistry.default as? KubesenseCore

        Kubesense.setAccountInfo(
            id: "foo",
            name: "bar",
            extraInfo: ["abc": 123]
        )

        Kubesense.addAccountExtraInfo(["abc": nil, "second": 667])

        XCTAssertEqual(core?.accountInfoPublisher.current?.id, "foo")
        XCTAssertEqual(core?.accountInfoPublisher.current?.name, "bar")
        XCTAssertEqual(core?.accountInfoPublisher.current?.extraInfo as? [String: Int], ["second": 667])

        Kubesense.flushAndDeinitialize()
    }

    func testAddAccountProperties_overwritesProperties() {
        Kubesense.initialize(
            with: defaultConfig,
            trackingConsent: .mockRandom()
        )

        let core = CoreRegistry.default as? KubesenseCore

        Kubesense.setAccountInfo(
            id: "foo",
            name: "bar",
            extraInfo: ["abc": 123]
        )

        Kubesense.addAccountExtraInfo(["abc": 444])

        XCTAssertEqual(core?.accountInfoPublisher.current?.id, "foo")
        XCTAssertEqual(core?.accountInfoPublisher.current?.name, "bar")
        XCTAssertEqual(core?.accountInfoPublisher.current?.extraInfo as? [String: Int], ["abc": 444])

        Kubesense.flushAndDeinitialize()
    }

    func testDefaultVerbosityLevel() {
        XCTAssertNil(Kubesense.verbosityLevel)
    }

    func testGivenDataStoredInAllFeatureDirectories_whenClearAllDataIsUsed_allFilesAreRemoved() throws {
        Kubesense.initialize(
            with: defaultConfig,
            trackingConsent: .mockRandom()
        )

        Logs.enable()
        Trace.enable()

        let core = try XCTUnwrap(CoreRegistry.default as? KubesenseCore)

        // On SDK init, underlying `ConsentAwareDataWriter` performs data migration for each feature, which includes
        // data removal in `unauthorised` (`.pending`) directory. To not cause test flakiness, we must ensure that
        // mock data is written only after this operation completes - otherwise, migration may delete mocked files.
        core.readWriteQueue.sync {}

        // Given
        let featureDirectories: [FeatureDirectories] = [
            try core.directory.getFeatureDirectories(forFeatureNamed: "logging"),
            try core.directory.getFeatureDirectories(forFeatureNamed: "tracing"),
        ]

        let scope = core.scope(for: TraceFeature.self)
        scope.dataStore.setValue("foo".data(using: .utf8)!, forKey: "bar")

        // Wait for async clear completion in all features:
        core.readWriteQueue.sync {}
        let tracingDataStoreDir = try core.directory.coreDirectory.subdirectory(path: core.directory.getDataStorePath(forFeatureNamed: "tracing"))
        XCTAssertTrue(tracingDataStoreDir.hasFile(named: "bar"))

        var allDirectories: [Directory] = featureDirectories.flatMap { [$0.authorized, $0.unauthorized] }
        allDirectories.append(.init(url: tracingDataStoreDir.url))
        try allDirectories.forEach { directory in _ = try directory.createFile(named: .mockRandom()) }

        // When
        Kubesense.clearAllData()

        // Wait for async clear completion in all features:
        core.readWriteQueue.sync {}

        // Then
        let files: [File] = allDirectories.reduce([], { acc, nextDirectory in
            let next = try? nextDirectory.files()
            return acc + (next ?? [])
        })
        XCTAssertEqual(files, [], "All files must be removed")

        Kubesense.flushAndDeinitialize()
    }

    func testServerDateProvider() throws {
        // Given
        var config = defaultConfig
        let serverDateProvider = ServerDateProviderMock()
        config.serverDateProvider = serverDateProvider

        // When
        Kubesense.initialize(
            with: config,
            trackingConsent: .mockRandom()
        )

        serverDateProvider.offset = -1

        // Then
        let core = try XCTUnwrap(CoreRegistry.default as? KubesenseCore)
        let context = core.contextProvider.read()
        XCTAssertEqual(context.serverTimeOffset, -1)

        Kubesense.flushAndDeinitialize()
    }

    func testRemoveV1DeprecatedFolders() throws {
        // Given
        let cache = try Directory.cache()
        let directories = ["ai.kubesense.logs", "ai.kubesense.traces", "ai.kubesense.rum"]
        try directories.forEach {
            _ = try cache.createSubdirectory(path: $0).createFile(named: "test")
        }

        // When
        Kubesense.initialize(
            with: defaultConfig,
            trackingConsent: .mockRandom()
        )

        defer { Kubesense.flushAndDeinitialize() }

        let core = try XCTUnwrap(CoreRegistry.default as? KubesenseCore)
        // Wait for async deletion
        core.readWriteQueue.sync {}

        // Then
        XCTAssertThrowsError(try cache.subdirectory(path: "ai.kubesense.logs"))
        XCTAssertThrowsError(try cache.subdirectory(path: "ai.kubesense.traces"))
        XCTAssertThrowsError(try cache.subdirectory(path: "ai.kubesense.rum"))
    }

    // MARK: Remote Configuration

    func testGivenRemoteConfigurationDisabled_providerIsNotCreated() throws {
        // When
        Kubesense.initialize(with: defaultConfig, trackingConsent: .granted)
        defer { Kubesense.flushAndDeinitialize() }

        // Then
        let core = try XCTUnwrap(CoreRegistry.default as? KubesenseCore)
        XCTAssertNil(core.remoteConfigurationProvider)
    }

    func testGivenRemoteConfigurationEnabled_itIsFetchedFromTheCollector() throws {
        // Given
        var config = defaultConfig
        config.remoteConfigurationEnabled = true
        config.httpClientFactory = { _ in HTTPClientMock() }

        // When
        Kubesense.initialize(with: config, trackingConsent: .granted)
        defer { Kubesense.flushAndDeinitialize() }

        // Then
        let core = try XCTUnwrap(CoreRegistry.default as? KubesenseCore)
        let provider = try XCTUnwrap(core.remoteConfigurationProvider)
        XCTAssertEqual(provider.configurationURL.absoluteString, "https://us2.kubesense.ai/rum/api/v1/sdk-config")
        XCTAssertEqual(provider.refreshPeriod, Kubesense.Configuration.defaultRemoteConfigurationRefreshPeriod)
        XCTAssertNil(core.contextProvider.read().remoteConfigurationId)
    }

    func testRemoteConfigurationIsEnabledByDefault() {
        let config = Kubesense.Configuration(clientToken: "abc-123", env: "tests")
        XCTAssertTrue(config.remoteConfigurationEnabled)
        XCTAssertEqual(config.remoteConfigurationRefreshPeriod, 6 * 60 * 60)
    }

    // MARK: Collector endpoint

    func testGivenNoKubesenseRumEndpoint_itUploadsToTheSiteCollector() throws {
        var config = defaultConfig
        config.site = .staging

        Kubesense.initialize(with: config, trackingConsent: .granted)
        defer { Kubesense.flushAndDeinitialize() }

        let core = try XCTUnwrap(CoreRegistry.default as? KubesenseCore)
        XCTAssertEqual(core.contextProvider.read().intakeEndpoint.absoluteString, "https://dev.kubesense.ai/")
    }

    func testGivenKubesenseRumEndpoint_everyFeatureUploadsToIt() throws {
        var config = defaultConfig
        config.kubesenseRumEndpoint = "http://collector.example.com:8443/some/path"

        Kubesense.initialize(with: config, trackingConsent: .granted)
        defer { Kubesense.flushAndDeinitialize() }

        let core = try XCTUnwrap(CoreRegistry.default as? KubesenseCore)
        XCTAssertEqual(core.contextProvider.read().intakeEndpoint.absoluteString, "https://collector.example.com:8443")
    }

    func testKubesenseRumEndpointIsNormalizedToAnHTTPSHost() {
        func resolved(_ value: String?) -> String? {
            var config = defaultConfig
            config.kubesenseRumEndpoint = value
            return config.kubesenseRumEndpointURL?.absoluteString
        }
        XCTAssertEqual(resolved("intake.example.com"), "https://intake.example.com")
        XCTAssertEqual(resolved("  https://intake.example.com/  "), "https://intake.example.com")
        XCTAssertEqual(resolved("HTTP://intake.example.com:8080/rum/api/v1"), "https://intake.example.com:8080")
        XCTAssertNil(resolved(nil))
        XCTAssertNil(resolved(""))
        XCTAssertNil(resolved("https://"))
    }

    func testGivenRemoteConfigurationEnabled_itIsStoredInPersistentDirectoryNotCaches() throws {
        // Given — distinct injected locations for purgeable caches vs. persistent storage
        let cachesDirectory = Directory(url: obtainUniqueTemporaryDirectory())
        let persistentDirectory = Directory(url: obtainUniqueTemporaryDirectory())
        var config = defaultConfig
        config.remoteConfigurationEnabled = true
        config.systemDirectory = { cachesDirectory }
        config.persistentDirectory = { persistentDirectory }
        config.httpClientFactory = { _ in HTTPClientMock() }

        // When
        Kubesense.initialize(with: config, trackingConsent: .granted)
        defer { Kubesense.flushAndDeinitialize() }

        // Then — remote configuration must live under Application Support, never the purgeable caches
        let core = try XCTUnwrap(CoreRegistry.default as? KubesenseCore)
        let rcPath = try XCTUnwrap(core.remoteConfigurationProvider?.directory.url.path)
        XCTAssertTrue(
            rcPath.hasPrefix(persistentDirectory.url.path),
            "Remote configuration must be stored under the persistent (Application Support) directory"
        )
        XCTAssertFalse(
            rcPath.hasPrefix(cachesDirectory.url.path),
            "Remote configuration must not be stored under the purgeable caches directory"
        )
    }

    func testCustomSDKInstance() throws {
        // When
        Kubesense.initialize(
            with: defaultConfig,
            trackingConsent: .mockRandom(),
            instanceName: "test"
        )

        defer { Kubesense.flushAndDeinitialize(instanceName: "test") }

        // Then
        XCTAssertTrue(CoreRegistry.default is NOPKubesenseCore)
        XCTAssertTrue(CoreRegistry.instance(named: "test") is KubesenseCore)
    }

    func testStopSDKInstance() throws {
        // Given
        Kubesense.initialize(
            with: defaultConfig,
            trackingConsent: .mockRandom(),
            instanceName: "test"
        )

        // Then
        XCTAssertTrue(CoreRegistry.instance(named: "test") is KubesenseCore)

        // When
        Kubesense.stopInstance(named: "test")

        // Then
        XCTAssertTrue(CoreRegistry.instance(named: "test") is NOPKubesenseCore)
    }

    func testGivenDefaultSDKInstanceInitialized_customOneCanBeInitializedAfterIt() throws {
        let defaultConfig = Kubesense.Configuration(clientToken: "abc-123", env: "default")
        let customConfig = Kubesense.Configuration(clientToken: "def-456", env: "custom")

        // Given
        Kubesense.initialize(
            with: defaultConfig,
            trackingConsent: .mockRandom()
        )
        defer { Kubesense.flushAndDeinitialize() }

        // When
        Kubesense.initialize(
            with: customConfig,
            trackingConsent: .mockRandom(),
            instanceName: "custom-instance"
        )
        defer { Kubesense.flushAndDeinitialize(instanceName: "custom-instance") }

        // Then
        XCTAssertTrue(CoreRegistry.default is KubesenseCore)
        XCTAssertTrue(CoreRegistry.instance(named: "custom-instance") is KubesenseCore)
    }
}
