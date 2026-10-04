/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import XCTest
import KubesenseInternal

class KubesenseSiteTests: XCTestCase {
    // MARK: - host per site (the Kubesense Android SDK's `KubesenseSite`)

    func testProdHost() { XCTAssertEqual(KubesenseSite.prod.host, "us2.kubesense.ai") }
    func testStagingHost() { XCTAssertEqual(KubesenseSite.staging.host, "dev.kubesense.ai") }

    // MARK: - endpoint per site

    func testProdEndpoint() { XCTAssertEqual(KubesenseSite.prod.endpoint.absoluteString, "https://us2.kubesense.ai/") }
    func testStagingEndpoint() { XCTAssertEqual(KubesenseSite.staging.endpoint.absoluteString, "https://dev.kubesense.ai/") }

    // MARK: - raw values, used in the SDK instance directory hash and by cross-platform SDKs

    func testRawValues() {
        XCTAssertEqual(KubesenseSite.prod.rawValue, "prod")
        XCTAssertEqual(KubesenseSite.staging.rawValue, "staging")
        XCTAssertEqual(KubesenseSite(rawValue: "prod"), .prod)
        XCTAssertNil(KubesenseSite(rawValue: "us1"))
    }

    // MARK: - upload paths, on the collector of each site

    func testUploadPathsAreAppendedToTheEndpoint() {
        let endpoint = KubesenseSite.prod.endpoint
        XCTAssertEqual(endpoint.appendingPathComponent("rum/api/v1").absoluteString, "https://us2.kubesense.ai/rum/api/v1")
        XCTAssertEqual(endpoint.appendingPathComponent("rum/api/v1/logs").absoluteString, "https://us2.kubesense.ai/rum/api/v1/logs")
    }
}
