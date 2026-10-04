/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import XCTest
import TestUtilities
import KubesenseInternal

@testable import KubesenseFlags

final class ExposureRequestBuilderTests: XCTestCase {
    private let mockEvents: [Event] = [
        .init(data: "event 1".utf8Data),
        .init(data: "event 2".utf8Data),
        .init(data: "event 3".utf8Data)
    ]

    func testItCreatesPOSTRequest() throws {
        // Given
        let builder = ExposureRequestBuilder(
            customIntakeURL: nil,
            telemetry: NOPTelemetry()
        )

        // When
        let request = try builder.request(for: mockEvents, with: .mockAny(), execution: .mockAny())

        // Then
        XCTAssertEqual(request.httpMethod, "POST")
    }

    func testItSetsExposuresIntakeURL() {
        // Given
        let builder = ExposureRequestBuilder(
            customIntakeURL: nil,
            telemetry: NOPTelemetry()
        )

        // When
        func url(for site: KubesenseSite) -> String {
            let request = try! builder.request(for: mockEvents, with: .mockWith(site: site), execution: .mockAny())
            return request.url!.absoluteStringWithoutQuery!
        }

        // Then
        XCTAssertEqual(url(for: .prod), "https://us2.kubesense.ai/rum/api/v1/exposures")
        XCTAssertEqual(url(for: .staging), "https://dev.kubesense.ai/rum/api/v1/exposures")
    }

    func testItSetsCustomIntakeURL() throws {
        // Given
        let randomURL: URL = .mockRandom()
        let builder = ExposureRequestBuilder(
            customIntakeURL: randomURL,
            telemetry: NOPTelemetry()
        )

        // When
        func url(for site: KubesenseSite) -> String {
            let request = try! builder.request(for: mockEvents, with: .mockWith(site: site), execution: .mockAny())
            return request.url!.absoluteStringWithoutQuery!
        }

        // Then
        let expectedURL = randomURL.absoluteStringWithoutQuery
        XCTAssertEqual(url(for: .prod), expectedURL)
        XCTAssertEqual(url(for: .staging), expectedURL)
    }

    func testItSetsExposureQueryParameters() throws {
        let randomSource: String = .mockRandom(among: .alphanumerics)

        // Given
        let builder = ExposureRequestBuilder(
            customIntakeURL: nil,
            telemetry: NOPTelemetry()
        )
        let context: KubesenseContext = .mockWith(source: randomSource)

        // When
        let request = try builder.request(for: mockEvents, with: context, execution: .mockAny())

        // Then
        let expectedQuery = "ksource=\(randomSource)"
        XCTAssertEqual(request.url?.query, expectedQuery)
    }

    func testItSetsExposureHTTPHeaders() throws {
        let randomApplicationName: String = .mockRandom(among: .alphanumerics)
        let randomVersion: String = .mockRandom(among: .decimalDigits)
        let randomSource: String = .mockRandom(among: .alphanumerics)
        let randomOrigin: String = .mockRandom(among: .alphanumerics)
        let randomSDKVersion: String = .mockRandom(among: .alphanumerics)
        let randomClientToken: String = .mockRandom()
        let randomDeviceName: String = .mockRandom()
        let randomDeviceOSName: String = .mockRandom()
        let randomDeviceOSVersion: String = .mockRandom()

        // Given
        let builder = ExposureRequestBuilder(
            customIntakeURL: nil,
            telemetry: NOPTelemetry()
        )
        let context: KubesenseContext = .mockWith(
            clientToken: randomClientToken,
            version: randomVersion,
            source: randomSource,
            sdkVersion: randomSDKVersion,
            ciAppOrigin: randomOrigin,
            applicationName: randomApplicationName,
            device: .mockWith(name: randomDeviceName),
            os: .mockWith(
                name: randomDeviceOSName,
                version: randomDeviceOSVersion
            )
        )

        // When
        let request = try builder.request(for: mockEvents, with: context, execution: .mockAny())

        // Then
        XCTAssertEqual(
            request.allHTTPHeaderFields?["User-Agent"],
            """
            \(randomApplicationName)/\(randomVersion) CFNetwork (\(randomDeviceName); \(randomDeviceOSName)/\(randomDeviceOSVersion))
            """
        )
        XCTAssertEqual(request.allHTTPHeaderFields?["Content-Type"], "text/plain;charset=UTF-8")
        XCTAssertEqual(request.allHTTPHeaderFields?["KUBESENSE-API-KEY"], randomClientToken)
        XCTAssertEqual(request.allHTTPHeaderFields?["KUBESENSE-EVP-ORIGIN"], randomOrigin)
        XCTAssertEqual(request.allHTTPHeaderFields?["KUBESENSE-EVP-ORIGIN-VERSION"], randomSDKVersion)
        XCTAssertEqual(request.allHTTPHeaderFields?["KUBESENSE-REQUEST-ID"]?.matches(regex: .uuidRegex), true)
    }

    func testItSetsHTTPBodyInExpectedFormat() throws {
        // Given
        let builder = ExposureRequestBuilder(
            customIntakeURL: nil,
            telemetry: NOPTelemetry()
        )

        // When
        let request = try builder.request(for: mockEvents, with: .mockAny(), execution: .mockAny())

        // Then
        let httpBodyData = try XCTUnwrap(request.httpBody)
        let actual = String(data: httpBodyData, encoding: .utf8)
        let expected = """
        event 1
        event 2
        event 3
        """
        XCTAssertEqual(expected, actual, "It must separate each event with newline character")
    }
}
