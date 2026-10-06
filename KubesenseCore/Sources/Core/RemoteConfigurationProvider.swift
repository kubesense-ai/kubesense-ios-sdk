/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import Foundation
import KubesenseInternal

/// On-disk representation of a cached remote configuration.
///
/// The HTTP ETag, the propagation metadata, and the configuration payload itself are kept
/// together and written in a single atomic file, so metadata can never point at a
/// configuration version that was not durably cached (and vice versa).
internal struct RemoteConfigurationCache: Codable {
    /// Propagation metadata for a cached remote configuration, used to correlate configuration
    /// propagation telemetry with the CDN version that produced it.
    struct Metadata: Codable, Equatable {
        /// Value of the `x-amz-version-id` response header.
        let versionId: String?
        /// Parsed value of the `last-modified` response header.
        let lastModified: Date?
        /// Date this configuration was fetched and persisted.
        let lastSynced: Date?
        /// Identifier of the sync that produced this configuration version, generated the same
        /// way as the request IDs used for event uploads. Reused by every session running on
        /// this version, until the next genuine (non-304) sync.
        let syncId: String?
        /// Date this configuration version was first observed as applied. Stamped once and
        /// reused on every subsequent session that runs on the same version.
        let firstApplied: Date?
    }

    /// Value of the `etag` response header, sent back as `If-None-Match`.
    let etag: String?
    /// Propagation metadata for `configuration`, if it was successfully cached.
    let metadata: Metadata?
    /// The raw response body of the last cached (or attempted) fetch, cached alongside `etag`
    /// even when decoding fails or the current SDK does not recognize every key. Decoding this
    /// fresh on every read (rather than persisting an already-decoded payload) lets an SDK
    /// upgrade that adds support for a previously-unknown key recover it from a payload cached
    /// before the upgrade, instead of waiting for the server document to change and bust the
    /// `ETag`.
    let configurationData: Data?

    init(etag: String?, metadata: Metadata?, configurationData: Data?) {
        self.etag = etag
        self.metadata = metadata
        self.configurationData = configurationData
    }
}

extension RemoteConfigurationCache.Metadata {
    /// Formats and parses the `last-modified` response header (RFC 7231 IMF-fixdate,
    /// e.g. `Wed, 21 Oct 2015 07:28:00 GMT`).
    static let httpDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter
    }()
}

/// Fetches and caches the Kubesense remote SDK configuration.
///
/// The lifecycle is fetch → cache → apply at next launch, like the Kubesense Android SDK's
/// `KubesenseRemoteConfig`:
/// - `readCachedDocument()` and `start(_:telemetry:)` read the small document cached by a previous
///   launch (never a network call). The core applies it to its own settings and features apply it as
///   they are enabled. First launch, offline launches and unreadable caches all yield no document, i.e.
///   pure SDK defaults.
/// - `start(_:telemetry:)` then fetches `GET <collector>/rum/api/v1/sdk-config` in the background,
///   authenticated with the SDK's client token, and only overwrites the cache with a payload that
///   parsed into a non-empty document. Any failure (network, non-2xx, malformed body) leaves the
///   current cache in place. A fetched document is not delivered to already running features: it
///   applies at the next launch.
/// - The document is re-fetched every `refreshPeriod` (at least one minute; never when the period is
///   zero or less) and, on UIKit platforms, when the app returns to the foreground (at most every
///   five minutes), for long running apps that rarely restart.
///
/// ## Caching
/// A successful fetch is persisted as `<id>.json` inside the supplied `directory`, as a single
/// `RemoteConfigurationCache` document combining the HTTP ETag (if the collector sends one), the
/// propagation metadata used for configuration telemetry, and the configuration payload.
///
/// ## Threading
/// - The synchronous cache reads run on the caller's thread.
/// - The network completion runs on an internal URLSession delegate queue (not the main thread).
///
/// ## Lifecycle
/// Call `stop()` (or let the instance deinit) to unsubscribe from foreground notifications and
/// cancel the periodic refresh.
internal final class RemoteConfigurationProvider {
    /// The name of the cache file (without extension), also reported as the configuration id in telemetry.
    static let cacheFileName = "kubesense-sdk-config"
    /// The collector path serving the remote configuration document.
    static let configurationPath = "rum/api/v1/sdk-config"
    /// The shortest interval between two periodic refreshes.
    static let minimumRefreshPeriod: TimeInterval = 60

    let id: String = RemoteConfigurationProvider.cacheFileName
    /// The collector base URL, e.g. `https://us2.kubesense.ai`.
    let endpoint: URL
    let clientToken: String
    let refreshPeriod: TimeInterval
    let directory: Directory
    let httpClient: HTTPClient

    private let notificationCenterProvider: NotificationCenterProvider
    private let dateProvider: DateProvider
    private let minimumSyncInterval: TimeInterval = 300
    @ReadWriteLock
    private var lastSyncDate: Date? = nil
    @ReadWriteLock
    private var foregroundObserver: NSObjectProtocol?
    @ReadWriteLock
    private var refreshTimer: DispatchSourceTimer?

    init(
        endpoint: URL,
        clientToken: String,
        directory: Directory,
        httpClient: HTTPClient,
        notificationCenterProvider: NotificationCenterProvider,
        refreshPeriod: TimeInterval = Kubesense.Configuration.defaultRemoteConfigurationRefreshPeriod,
        dateProvider: DateProvider = SystemDateProvider()
    ) {
        self.endpoint = endpoint
        self.clientToken = clientToken
        self.refreshPeriod = refreshPeriod
        self.directory = directory
        self.httpClient = httpClient
        self.notificationCenterProvider = notificationCenterProvider
        self.dateProvider = dateProvider
    }

    /// The URL the remote configuration document is fetched from.
    var configurationURL: URL {
        endpoint.appendingPathComponent(Self.configurationPath)
    }

    /// Reads the document cached by a previous launch, without reporting anything. Never touches the network.
    ///
    /// - Returns: The cached document, or `.empty` when there is none or it cannot be read.
    func readCachedDocument() -> RemoteConfigDocument {
        readCache(telemetry: NOPTelemetry(), report: false) ?? .empty
    }

    /// Starts the provider.
    ///
    /// `handler` is called synchronously with the cached document, if one exists on disk. Documents
    /// fetched afterwards are cached for the next launch and are not delivered.
    ///
    /// - Parameters:
    ///   - handler: Called with the cached document, if any. Read or fetch errors are not surfaced here;
    ///     they are reported to `telemetry` instead.
    ///   - telemetry: Reports the propagation of the configuration version delivered from cache (if any)
    ///     on the once-per-session configuration telemetry, and read or fetch errors.
    func start(
        _ handler: @escaping (RemoteConfigDocument) -> Void,
        telemetry: Telemetry = NOPTelemetry()
    ) {
        // Synchronous read on the caller's thread (main thread during SDK init).
        // Acceptable because the file is small (a single JSON document) and only
        // present after a previous successful fetch — absent on first launch.
        readCache(telemetry: telemetry, report: true).map(handler)

#if os(macOS)
        foregroundObserver = notificationCenterProvider.workspaceCenter.addObserver(
            forName: WorkspaceNotifications.didWake,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let self else {
                return
            }
            if let last = self.lastSyncDate {
                let elapsed = self.dateProvider.now.timeIntervalSince(last)
                if elapsed >= 0, elapsed < self.minimumSyncInterval {
                    return
                }
            }
            self.sync(handler, telemetry: telemetry)
        }
#elseif canImport(UIKit)
        foregroundObserver = notificationCenterProvider.applicationCenter.addObserver(
            forName: ApplicationNotifications.willEnterForeground,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let self else {
                return
            }
            if let last = self.lastSyncDate {
                let elapsed = self.dateProvider.now.timeIntervalSince(last)
                if elapsed >= 0, elapsed < self.minimumSyncInterval {
                    return
                }
            }
            self.sync(telemetry: telemetry)
        }
#endif

        schedulePeriodicRefresh(telemetry: telemetry)
        sync(telemetry: telemetry)
    }

    deinit {
        stop()
    }

    /// Stops the provider.
    ///
    /// Unsubscribes from foreground notifications and cancels the periodic refresh. Any network
    /// request already in flight may still complete, but its result is discarded because the
    /// `[weak self]` capture in the HTTP callback resolves to `nil`.
    ///
    /// Safe to call multiple times and from any thread.
    func stop() {
        _foregroundObserver.mutate { observer in
#if os(macOS)
            observer.map { notificationCenterProvider.workspaceCenter.removeObserver($0) }
#elseif canImport(UIKit)
            observer.map { notificationCenterProvider.applicationCenter.removeObserver($0) }
#endif
            observer = nil
        }
        _refreshTimer.mutate { timer in
            timer?.cancel()
            timer = nil
        }
    }

    // MARK: - Private

    private func schedulePeriodicRefresh(telemetry: Telemetry) {
        guard refreshPeriod > 0 else {
            return
        }
        let period = max(refreshPeriod, Self.minimumRefreshPeriod)
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now() + period, repeating: period)
        timer.setEventHandler { [weak self] in
            self?.sync(telemetry: telemetry)
        }
        _refreshTimer.mutate { current in
            current?.cancel()
            current = timer
        }
        timer.resume()
    }

    private func readCache(telemetry: Telemetry, report reportsTelemetry: Bool) -> RemoteConfigDocument? {
        let cacheFilename = "\(id).json"
        guard directory.hasFile(named: cacheFilename) else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            let data = try directory.file(named: cacheFilename).read()
            let cache = try decoder.decode(RemoteConfigurationCache.self, from: data)

            // Parse fresh from `configurationData` on every read rather than persisting an
            // already-parsed payload — see its doc comment.
            guard let configurationData = cache.configurationData else {
                return nil
            }
            let document = RemoteConfigDocument.parse(configurationData)
            guard !document.isEmpty else {
                return nil
            }

            if reportsTelemetry {
                report(cache: cache, to: telemetry)
            }

            return document
        } catch {
            telemetry.error("[RemoteConfig] Failed to read cached remote configuration", error: error)
            return nil
        }
    }

    /// Fires an async fetch and persists the document on success, for the next launch.
    private func sync(telemetry: Telemetry) {
        let decoder = JSONDecoder()
        let cacheFilename = "\(id).json"

        var request = URLRequest(url: configurationURL)
        request.httpMethod = "GET"
        request.setValue(clientToken, forHTTPHeaderField: URLRequestBuilder.HTTPHeader.kubesenseAPIKeyHeaderField)
        // Keep the SDK's own configuration request out of RUM's automatic `URLSession` instrumentation,
        // without altering the request sent over the wire.
        URLRequestBuilder.markAsInternal(&request)

        var cache: RemoteConfigurationCache?
        if let file = try? directory.file(named: cacheFilename) {
            do {
                cache = try decoder.decode(RemoteConfigurationCache.self, from: file.read())
                cache?.etag.map { request.setValue($0, forHTTPHeaderField: "If-None-Match") }
            } catch {
                telemetry.error("[RemoteConfig] Failed to read cached metadata etag", error: error)
            }
        }

        httpClient.send(request: request, delegate: nil) { [weak self] result in
            guard let self else {
                return
            }

            do {
                let (http, data) = try result.get()

                if http.statusCode == 304 {
                    self.lastSyncDate = self.dateProvider.now
                    return
                }

                guard (200..<300).contains(http.statusCode) else {
                    throw RemoteConfigurationError.httpError(http.statusCode)
                }

                guard let data, !data.isEmpty else {
                    // Still update the ETag so a known-bad payload is not re-fetched on every
                    // sync; we recover once the server publishes an update. Previously cached
                    // configuration and metadata are left untouched.
                    self.updateETag(from: http, previous: cache, telemetry: telemetry)
                    throw RemoteConfigurationError.emptyBody
                }

                guard !RemoteConfigDocument.parse(data).isEmpty else {
                    // A payload that is not a usable document never replaces the cached one.
                    self.updateETag(from: http, previous: cache, telemetry: telemetry)
                    throw RemoteConfigurationError.invalidPayload
                }

                // Persist configuration, metadata, and etag together in a single atomic write
                // (File.write uses .atomic: write to temp, then rename). The new document applies at
                // the next launch; features already running keep the one they were enabled with.
                try self.saveCache(data: data, from: http)

                self.lastSyncDate = self.dateProvider.now
            } catch {
                telemetry.error("[RemoteConfig] Failed to sync remote configuration", error: error)
            }
        }
    }

    /// Reports the configuration version applied from cache on the once-per-session
    /// configuration telemetry. Stamps `firstApplied` the first time this version is
    /// observed as applied, and persists it back to disk so every later session running
    /// on the same version reports the same value.
    private func report(cache: RemoteConfigurationCache, to telemetry: Telemetry) {
        guard var metadata = cache.metadata else {
            return
        }

        if metadata.firstApplied == nil {
            metadata = RemoteConfigurationCache.Metadata(
                versionId: metadata.versionId,
                lastModified: metadata.lastModified,
                lastSynced: metadata.lastSynced,
                syncId: metadata.syncId,
                firstApplied: dateProvider.now
            )
            do {
                try write(
                    cache: RemoteConfigurationCache(
                        etag: cache.etag,
                        metadata: metadata,
                        configurationData: cache.configurationData
                    )
                )
            } catch {
                telemetry.error("[RemoteConfig] Failed to save remote configuration metadata", error: error)
            }
        }

        telemetry.configuration(
            remoteConfiguration: .init(
                configId: id,
                versionId: metadata.versionId,
                lastModified: metadata.lastModified,
                lastSynced: metadata.lastSynced,
                firstApplied: metadata.firstApplied,
                syncId: metadata.syncId
            )
        )
    }

    /// Builds and persists the cache from a genuine (non-304) fetch's HTTP response, once the
    /// fetched configuration has been successfully decoded. `syncId` and `lastSynced` mark this
    /// as a genuine sync, distinct from a 304. `firstApplied` is left unset: this version has
    /// not been applied yet, since a fetch that completes mid-session does not retroactively
    /// re-apply already initialized features.
    ///
    /// Throws if the write fails, so the caller can treat an undelivered, uncached configuration
    /// as a failed sync rather than deliver a configuration that was never durably persisted.
    private func saveCache(data: Data, from response: HTTPURLResponse) throws {
        let etag = response.allHeaderFields.first(where: { ($0.key as? String)?.lowercased() == "etag" })?.value as? String
        let versionId = response.allHeaderFields.first(where: { ($0.key as? String)?.lowercased() == "x-amz-version-id" })?.value as? String
        let lastModifiedHeader = response.allHeaderFields.first(where: { ($0.key as? String)?.lowercased() == "last-modified" })?.value as? String

        let cache = RemoteConfigurationCache(
            etag: etag,
            metadata: RemoteConfigurationCache.Metadata(
                versionId: versionId,
                lastModified: lastModifiedHeader.flatMap { RemoteConfigurationCache.Metadata.httpDateFormatter.date(from: $0) },
                lastSynced: dateProvider.now,
                syncId: UUID().uuidString,
                firstApplied: nil
            ),
            configurationData: data
        )

        try write(cache: cache)
    }

    /// Persists only the response's `ETag`, leaving any previously cached configuration and
    /// metadata untouched.
    ///
    /// Called when the response body could not be cached or decoded, so the next sync sends
    /// `If-None-Match` for this same (still-broken) payload and short-circuits to a lightweight
    /// 304 instead of re-fetching and re-failing on every sync, without `report(cache:to:)`
    /// ever reporting this undelivered version as applied.
    private func updateETag(from response: HTTPURLResponse, previous: RemoteConfigurationCache?, telemetry: Telemetry) {
        let etag = response.allHeaderFields.first(where: { ($0.key as? String)?.lowercased() == "etag" })?.value as? String

        let cache = RemoteConfigurationCache(
            etag: etag,
            metadata: previous?.metadata,
            configurationData: previous?.configurationData
        )

        do {
            try write(cache: cache)
        } catch {
            telemetry.error("[RemoteConfig] Failed to save remote configuration metadata", error: error)
        }
    }

    /// Persists the cache to `<id>.json`.
    private func write(cache: RemoteConfigurationCache) throws {
        try write(JSONEncoder().encode(cache), to: "\(id).json")
    }

    private func write(_ data: Data, to filename: String) throws {
        let file = directory.hasFile(named: filename)
            ? try directory.file(named: filename)
            : try directory.createFile(named: filename)
        try file.write(data: data)
    }
}

internal enum RemoteConfigurationError: Error, LocalizedError {
    case httpError(Int)
    case emptyBody
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .httpError(let code): return "Non-2xx response: HTTP \(code)"
        case .emptyBody: return "Empty response body"
        case .invalidPayload: return "Response body is not a remote configuration document"
        }
    }
}
