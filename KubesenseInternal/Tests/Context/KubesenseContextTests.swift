/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import KubesenseInternal
import TestUtilities
import XCTest

final class KubesenseContextTests: XCTestCase {
    // MARK: - Test ktags

    func testKubesenseDDTags() throws {
        // Given
        let service: String = .mockRandom()
        let env: String = .mockRandom()
        let version: String = .mockRandom()
        let sdkVersion: String = .mockRandom()
        let variant: String = .mockRandom()
        let kubesenseContext: KubesenseContext = .mockWith(
            service: service,
            env: env,
            version: version,
            variant: variant,
            sdkVersion: sdkVersion
        )

        // Then
        let kubesenseTagsArray = kubesenseContext.kubesenseTags.split(separator: ",")

        let kubesenseTags = kubesenseTagsArray.reduce(into: [:]) {
            let item = $1.split(separator: ":")
            $0[String(item[0])] = String(item[1])
        }

        XCTAssertEqual(kubesenseTags["service"] as! String, service)
        XCTAssertEqual(kubesenseTags["env"] as! String, env)
        XCTAssertEqual(kubesenseTags["version"] as! String, version)
        XCTAssertEqual(kubesenseTags["sdk_version"] as! String, sdkVersion)
        XCTAssertEqual(kubesenseTags["variant"] as! String, variant)
    }

    func testKubesenseSanitizedDDTags() throws {
        // Given
        let service = "service:with:colons"
        let env = "prod,dev"
        let version = "1,2,3"
        let sdkVersion = "3,2,1"
        let variant = "variant,with,commas:"
        let kubesenseContext: KubesenseContext = .mockWith(
            service: service,
            env: env,
            version: version,
            variant: variant,
            sdkVersion: sdkVersion
        )

        // Then
        let kubesenseTagsArray = kubesenseContext.kubesenseTags.split(separator: ",")

        let kubesenseTags = kubesenseTagsArray.reduce(into: [:]) {
            let item = $1.split(separator: ":")
            $0[String(item[0])] = String(item[1])
        }

        XCTAssertEqual(kubesenseTags["service"] as! String, "servicewithcolons")
        XCTAssertEqual(kubesenseTags["env"] as! String, "proddev")
        XCTAssertEqual(kubesenseTags["version"] as! String, "123")
        XCTAssertEqual(kubesenseTags["sdk_version"] as! String, "321")
        XCTAssertEqual(kubesenseTags["variant"] as! String, "variantwithcommas")
    }

    func testKubesenseDDTagsWithoutVariant() throws {
        // Given
        let service: String = .mockRandom()
        let env: String = .mockRandom()
        let version: String = .mockRandom()
        let sdkVersion: String = .mockRandom()
        let kubesenseContext: KubesenseContext = .mockWith(
            service: service,
            env: env,
            version: version,
            variant: nil,
            sdkVersion: sdkVersion
        )

        // Then
        let kubesenseTagsArray = kubesenseContext.kubesenseTags.split(separator: ",")

        let kubesenseTags = kubesenseTagsArray.reduce(into: [:]) {
            let item = $1.split(separator: ":")
            $0[String(item[0])] = String(item[1])
        }

        XCTAssertEqual(kubesenseTags["service"] as! String, service)
        XCTAssertEqual(kubesenseTags["env"] as! String, env)
        XCTAssertEqual(kubesenseTags["version"] as! String, version)
        XCTAssertEqual(kubesenseTags["sdk_version"] as! String, sdkVersion)
        XCTAssertNil(kubesenseTags["variant"])
    }

    // MARK: - kubesenseTags caching

    func testDDTagsUpdatesWhenVersionChanges() throws {
        // Given
        var context: KubesenseContext = .mockWith(version: "1.0.0")
        let originalDDTags = context.kubesenseTags
        XCTAssertTrue(originalDDTags.contains("version:1.0.0"))

        // When
        context.version = "2.0.0"

        // Then
        XCTAssertTrue(context.kubesenseTags.contains("version:2.0.0"))
        XCTAssertFalse(context.kubesenseTags.contains("version:1.0.0"))
        XCTAssertNotEqual(context.kubesenseTags, originalDDTags)
    }

    func testDDTagsSanitizesVersionOnUpdate() throws {
        // Given
        var context: KubesenseContext = .mockWith(version: "1.0.0")

        // When
        context.version = "2,0:0"

        // Then
        XCTAssertEqual(context.version, "200")
        XCTAssertTrue(context.kubesenseTags.contains("version:200"))
    }

    // MARK: - KubesenseTag.merge

    func testMergeDDTags_whenOtherTagsIsNilOrEmpty_itReturnsNativeTagsUnchanged() {
        let nativeTags = "service:app,version:1.0.0,sdk_version:5.0.0,env:prod"

        XCTAssertEqual(KubesenseTag.merge(nativeTags, with: nil), nativeTags)
        XCTAssertEqual(KubesenseTag.merge(nativeTags, with: ""), nativeTags)
    }

    func testMergeDDTags_whenOtherTagsHasNoOverlappingKeys_itAppendsThem() {
        let merged = KubesenseTag.merge(
            "service:app,version:1.0.0,sdk_version:5.0.0,env:prod",
            with: "browser_sdk_version:3.6.13"
        )

        XCTAssertEqual(merged, "browser_sdk_version:3.6.13,env:prod,sdk_version:5.0.0,service:app,version:1.0.0")
    }

    func testMergeDDTags_whenOtherTagsHasOverlappingKeys_itOverridesNativeValuesInPlace() {
        let merged = KubesenseTag.merge(
            "service:app,version:1.0.0,sdk_version:5.0.0,env:prod",
            with: "sdk_version:3.6.13,browser_sdk_version:3.6.13"
        )

        XCTAssertEqual(merged, "browser_sdk_version:3.6.13,env:prod,sdk_version:3.6.13,service:app,version:1.0.0")
    }

    func testMergeDDTags_itIgnoresPairsWithoutAColon() {
        let merged = KubesenseTag.merge(
            "service:app,version:1.0.0",
            with: "malformed,env:prod"
        )

        XCTAssertEqual(merged, "env:prod,service:app,version:1.0.0")
    }
}
