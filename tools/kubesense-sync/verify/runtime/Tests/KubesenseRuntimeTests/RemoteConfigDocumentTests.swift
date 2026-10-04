/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Kubesense addition to the fork of dd-sdk-ios, see docs/UPSTREAM_SYNC.md.
 */

import Foundation
import Testing
import KubesenseInternal

@Suite
struct RemoteConfigDocumentTests {
    private func parse(_ json: String) -> RemoteConfigDocument {
        RemoteConfigDocument.parse(Data(json.utf8))
    }

    // MARK: - Parsing

    @Test("Anything but a JSON object is an empty document", arguments: ["", "not json", "[]", "[{}]", "42", "\"rum\"", "null", "{}"])
    func nonObjectsAreEmpty(json: String) {
        let document = parse(json)
        #expect(document.isEmpty)
        #expect(document == .empty)
    }

    @Test("A document with only top-level scalars is not empty, but carries no section")
    func topLevelScalarsOnly() {
        let document = parse(#"{"version": 1}"#)
        #expect(!document.isEmpty)
        #expect(document.sections.isEmpty)
    }

    @Test("Reads the typed values of the collector's example document")
    func readsTypedValues() {
        let document = parse("""
        {
          "version": 1,
          "features": { "rum": true, "logs": false },
          "rum": { "sessionSampleRate": 42.5, "trackFrustrations": true, "vitalsUpdateFrequency": "AVERAGE", "longTaskThresholdMs": 250 },
          "sessionReplay": { "imagePrivacy": "MASK_ALL", "minRAMSizeMb": 1024 }
        }
        """)
        #expect(document.bool("features", "rum") == true)
        #expect(document.bool("features", "logs") == false)
        #expect(document.sampleRate("rum", "sessionSampleRate") == 42.5)
        #expect(document.bool("rum", "trackFrustrations") == true)
        #expect(document.string("rum", "vitalsUpdateFrequency") == "AVERAGE")
        #expect(document.int64("rum", "longTaskThresholdMs") == 250)
        #expect(document.positiveInt("sessionReplay", "minRAMSizeMb") == 1_024)
    }

    @Test("Wrong types, missing keys and out of range values answer nil")
    func failSafeAccessors() {
        let document = parse("""
        { "rum": { "a": "true", "b": 1, "c": 101, "d": -1, "e": 0, "f": {"nested": true}, "g": [1] }, "flat": 3 }
        """)
        #expect(document.bool("rum", "a") == nil)
        #expect(document.bool("rum", "b") == nil)
        #expect(document.sampleRate("rum", "c") == nil)
        #expect(document.sampleRate("rum", "d") == nil)
        #expect(document.sampleRate("rum", "e") == 0)
        #expect(document.positiveInt("rum", "e") == nil)
        #expect(document.string("rum", "b") == nil)
        #expect(document.bool("rum", "f") == nil)
        #expect(document.number("rum", "g") == nil)
        #expect(document.number("flat", "anything") == nil)
        #expect(document.bool("missing", "key") == nil)
    }

    @Test("Enum names compare case-insensitively and ignore underscores")
    func enumValues() {
        let document = parse(#"{ "core": { "a": "MASK_ALL", "b": "maskAll", "c": "mask_all", "d": "MASK_LARGE_ONLY" } }"#)
        let values = ["MASK_ALL": 1]
        #expect(document.enumValue("core", "a", values) == 1)
        #expect(document.enumValue("core", "b", values) == 1)
        #expect(document.enumValue("core", "c", values) == 1)
        #expect(document.enumValue("core", "d", values) == nil)
    }

    // MARK: - Typed view for the RUM, Session Replay, Trace and Profiling merges

    @Test("An empty document has no typed view")
    func emptyDocumentHasNoTypedView() {
        #expect(RemoteConfiguration(document: .empty) == nil)
    }

    @Test("Maps the Android keys and enum names onto the typed model")
    func mapsTypedModel() throws {
        let document = parse("""
        {
          "rum": {
            "telemetrySampleRate": 20, "trackUserInteractions": false, "trackBackgroundEvents": true,
            "trackAnonymousUser": false, "vitalsUpdateFrequency": "RARE", "longTaskThresholdMs": 250,
            "appHangThresholdMs": 0
          },
          "sessionReplay": { "sampleRate": 50, "imagePrivacy": "MASK_NONE", "touchPrivacy": "SHOW", "textAndInputPrivacy": "MASK_ALL_INPUTS" },
          "trace": { "sampleRate": 10 },
          "profiling": { "launchSampleRate": 15 }
        }
        """)
        let configuration = try #require(RemoteConfiguration(document: document))

        #expect(configuration.rum?.telemetrySampleRate == 20)
        #expect(configuration.rum?.trackUserInteractions == false)
        #expect(configuration.rum?.trackBackgroundEvents == true)
        #expect(configuration.rum?.trackAnonymousUser == false)
        #expect(configuration.rum?.vitalsUpdateFrequency == .rare)
        #expect(configuration.rum?.longTask?.threshold == 250)
        #expect(configuration.rum?.longTask?.enabled == nil)
        // A non-positive threshold disables the feature.
        #expect(configuration.rum?.appHang?.enabled == false)
        #expect(configuration.rum?.appHang?.threshold == nil)
        #expect(configuration.rum?.trackFrustrations == nil)

        #expect(configuration.sessionReplay?.sampleRate == 50)
        #expect(configuration.sessionReplay?.imagePrivacy == .maskNone)
        #expect(configuration.sessionReplay?.touchPrivacy == .show)
        #expect(configuration.sessionReplay?.textAndInputPrivacy == .maskAllInputs)

        #expect(configuration.trace?.sampleRate == 10)
        #expect(configuration.trace?.tracedHosts == nil)
        #expect(configuration.profiling?.applicationLaunchSampleRate == 15)
    }
}
