/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Kubesense addition to the fork of dd-sdk-ios, see docs/UPSTREAM_SYNC.md.
 */

import Foundation

/// A parsed remote SDK configuration document, as served by the Kubesense collector on
/// `GET /rum/api/v1/sdk-config`.
///
/// The document is a two-level JSON object: named sections (`"rum"`, `"sessionReplay"`, `"logs"`,
/// `"trace"`, `"flags"`, `"profiling"`, `"core"`, `"features"`) holding scalar values:
///
/// ```json
/// {
///   "version": 1,
///   "features": { "logs": false },
///   "rum": { "sessionSampleRate": 100.0, "trackFrustrations": true },
///   "core": { "batchSize": "MEDIUM" }
/// }
/// ```
///
/// Every accessor is fail-safe and returns `nil` when the section or key is missing, has the wrong JSON
/// type, or holds an out-of-range value: the caller then leaves the corresponding setting as the
/// application configured it. A broken document can never take an app away from safe SDK defaults.
///
/// This is the same document, with the same keys, as the Kubesense Android SDK's `RemoteConfigDocument`.
public struct RemoteConfigDocument: Equatable, Sendable {
    /// A scalar value of the document.
    public enum Value: Equatable, Sendable {
        case bool(Bool)
        case number(Double)
        case string(String)
    }

    /// The sections of the document, each holding its scalar values by key.
    public let sections: [String: [String: Value]]

    /// Whether this document carries no remote values at all (missing or unusable cache).
    public let isEmpty: Bool

    /// A document with no remote values: every accessor answers `nil` (the SDK defaults apply).
    public static let empty = RemoteConfigDocument(sections: [:], isEmpty: true)

    public init(sections: [String: [String: Value]], isEmpty: Bool? = nil) {
        self.sections = sections
        self.isEmpty = isEmpty ?? sections.isEmpty
    }

    /// Parses `data` into a document. Anything that is not a JSON object (malformed payload, array,
    /// primitive) resolves to `.empty`, never to an error.
    public static func parse(_ data: Data) -> RemoteConfigDocument {
        guard let root = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return .empty
        }
        var sections: [String: [String: Value]] = [:]
        for (name, element) in root {
            guard let object = element as? [String: Any] else {
                continue
            }
            var values: [String: Value] = [:]
            for (key, raw) in object {
                if let value = Value(json: raw) {
                    values[key] = value
                }
            }
            sections[name] = values
        }
        return RemoteConfigDocument(sections: sections, isEmpty: root.isEmpty)
    }

    /// Reads a boolean value, or `nil` when absent or not a boolean.
    public func bool(_ section: String, _ key: String) -> Bool? {
        guard case let .bool(value)? = sections[section]?[key] else {
            return nil
        }
        return value
    }

    /// Reads a number, or `nil` when absent or not a number.
    public func number(_ section: String, _ key: String) -> Double? {
        guard case let .number(value)? = sections[section]?[key] else {
            return nil
        }
        return value
    }

    /// Reads a sample rate, or `nil` when absent, not a number, or outside `0...100`.
    public func sampleRate(_ section: String, _ key: String) -> Float? {
        guard let value = number(section, key), (0...100).contains(value) else {
            return nil
        }
        return Float(value)
    }

    /// Reads an integral value, or `nil` when absent, not a number, or not representable as `Int64`.
    public func int64(_ section: String, _ key: String) -> Int64? {
        guard let value = number(section, key), value.isFinite,
              value >= Double(Int64.min), value < Double(Int64.max) else {
            return nil
        }
        return Int64(value)
    }

    /// Reads a strictly positive integer, or `nil` when absent, not a number, or `<= 0`.
    public func positiveInt(_ section: String, _ key: String) -> Int? {
        guard let value = int64(section, key), value > 0, value <= Int64(Int.max) else {
            return nil
        }
        return Int(value)
    }

    /// Reads a string value, or `nil` when absent or not a string.
    public func string(_ section: String, _ key: String) -> String? {
        guard case let .string(value)? = sections[section]?[key] else {
            return nil
        }
        return value
    }

    /// Reads a string and maps it through `values`, comparing names case-insensitively. An unknown
    /// name answers `nil`, so that it falls back to the SDK default rather than failing.
    ///
    /// Enum constants are written the way the Android SDK names them (`"MASK_ALL"`, `"AVERAGE"`), which
    /// is why `_` is ignored in the comparison: `"MASK_ALL"`, `"mask_all"` and `"maskAll"` are all equal.
    public func enumValue<T>(_ section: String, _ key: String, _ values: [String: T]) -> T? {
        guard let name = string(section, key).map(Self.normalized) else {
            return nil
        }
        return values.first { Self.normalized($0.key) == name }?.value
    }

    private static func normalized(_ name: String) -> String {
        name.replacingOccurrences(of: "_", with: "").lowercased()
    }
}

extension RemoteConfigDocument.Value {
    init?(json: Any) {
        switch json {
        case let number as NSNumber:
            // `JSONSerialization` returns booleans as `NSNumber` too; tell them apart by their type.
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                self = .bool(number.boolValue)
            } else {
                self = .number(number.doubleValue)
            }
        case let string as String:
            self = .string(string)
        default:
            return nil
        }
    }
}

/// The names of the sections of the remote configuration document.
public enum RemoteConfigSection {
    /// Per-feature on/off switches: `"rum"`, `"logs"`, `"trace"`, `"sessionReplay"`, `"profiling"`, `"flags"`.
    public static let features = "features"
    /// The core upload pipeline: `batchSize`, `uploadFrequency`.
    public static let core = "core"
    public static let rum = "rum"
    public static let sessionReplay = "sessionReplay"
    public static let logs = "logs"
    public static let trace = "trace"
    public static let flags = "flags"
    public static let profiling = "profiling"
}

extension KubesenseCoreProtocol {
    /// Reports whether a feature was switched off from the dashboard, so that `enable()` can return without
    /// registering it. Only an explicit `false` disables a feature: an absent key, an unusable value, or no
    /// remote configuration at all leaves the application in control.
    ///
    /// - Parameters:
    ///   - featureKey: The key of the feature inside the `features` section, e.g. `"sessionReplay"`.
    ///   - featureName: The human readable name used in the log explaining the skip.
    public func isFeatureDisabledRemotely(featureKey: String, featureName: String) -> Bool {
        guard remoteConfigDocument.bool(RemoteConfigSection.features, featureKey) == false else {
            return false
        }
        KS.logger.warn("\(featureName) was not enabled: it is switched off in the remote configuration")
        return true
    }
}

extension RemoteConfiguration {
    /// Builds the typed remote configuration read by the RUM, Session Replay, Trace and Profiling
    /// `apply(remoteConfiguration:)` merges from a Kubesense remote configuration document.
    ///
    /// Only the values the document carries are set, so every setting it omits keeps its in-code value.
    /// Keys follow the Kubesense Android SDK where both SDKs have the setting (`rum.longTaskThresholdMs`,
    /// `profiling.launchSampleRate`, the upper-case enum names); settings only iOS has use the iOS
    /// property names (`rum.appHangThresholdMs`, `rum.trackWatchdogTerminations`, ...). Settings the typed
    /// model cannot express (`rum.sessionSampleRate`, the `logs`, `flags`, `core` and `features` sections,
    /// ...) are applied by the features themselves from the document.
    ///
    /// - Returns: `nil` for an empty document, so that "no remote configuration" stays `nil`.
    public init?(document: RemoteConfigDocument) {
        guard !document.isEmpty else {
            return nil
        }
        let rum = RemoteConfigSection.rum
        let sessionReplay = RemoteConfigSection.sessionReplay
        let profiling = RemoteConfigSection.profiling

        func threshold<T>(_ key: String, _ make: (Bool?, Double?) -> T) -> T? {
            guard let milliseconds = document.int64(rum, key) else {
                return nil
            }
            // A non-positive threshold disables the feature rather than configuring an impossible value,
            // like `trackLongTasks` does on Android.
            return milliseconds > 0 ? make(nil, Double(milliseconds)) : make(false, nil)
        }

        self.init(
            profiling: RemoteConfiguration.Profiling(
                applicationLaunchSampleRate: document.sampleRate(profiling, "launchSampleRate").map(Double.init),
                continuousSampleRate: document.sampleRate(profiling, "continuousSampleRate").map(Double.init)
            ),
            rum: RemoteConfiguration.RUM(
                appHang: threshold("appHangThresholdMs") { RemoteConfiguration.RUM.AppHang(enabled: $0, threshold: $1) },
                applicationId: "",
                longTask: threshold("longTaskThresholdMs") { RemoteConfiguration.RUM.LongTask(enabled: $0, threshold: $1) },
                telemetrySampleRate: document.sampleRate(rum, "telemetrySampleRate").map(Double.init),
                trackAnonymousUser: document.bool(rum, "trackAnonymousUser"),
                trackBackgroundEvents: document.bool(rum, "trackBackgroundEvents"),
                trackFrustrations: document.bool(rum, "trackFrustrations"),
                trackMemoryWarnings: document.bool(rum, "trackMemoryWarnings"),
                trackResources: document.bool(rum, "trackResources"),
                trackSlowFrames: document.bool(rum, "trackSlowFrames"),
                trackUserInteractions: document.bool(rum, "trackUserInteractions"),
                trackWatchdogTerminations: document.bool(rum, "trackWatchdogTerminations"),
                vitalsUpdateFrequency: document.enumValue(rum, "vitalsUpdateFrequency", [
                    "FREQUENT": .frequent,
                    "AVERAGE": .average,
                    "RARE": .rare,
                    "NEVER": .never,
                ])
            ),
            sessionReplay: RemoteConfiguration.SessionReplay(
                // Android's `MASK_LARGE_ONLY` has no iOS equivalent: it is ignored, keeping the in-code level.
                imagePrivacy: document.enumValue(sessionReplay, "imagePrivacy", [
                    "MASK_NONE": .maskNone,
                    "MASK_NON_BUNDLED_ONLY": .maskNonBundledOnly,
                    "MASK_ALL": .maskAll,
                ]),
                sampleRate: document.sampleRate(sessionReplay, "sampleRate").map(Double.init),
                textAndInputPrivacy: document.enumValue(sessionReplay, "textAndInputPrivacy", [
                    "MASK_SENSITIVE_INPUTS": .maskSensitiveInputs,
                    "MASK_ALL_INPUTS": .maskAllInputs,
                    "MASK_ALL": .maskAll,
                ]),
                touchPrivacy: document.enumValue(sessionReplay, "touchPrivacy", [
                    "SHOW": .show,
                    "HIDE": .hide,
                ])
            ),
            trace: RemoteConfiguration.Trace(
                sampleRate: document.sampleRate(RemoteConfigSection.trace, "sampleRate").map(Double.init)
            )
        )
    }
}
