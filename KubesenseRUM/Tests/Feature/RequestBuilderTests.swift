/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import XCTest
import TestUtilities
import KubesenseInternal
@testable import KubesenseRUM

class RequestBuilderTests: XCTestCase {
    private let mockEvents: [Event] = [
        .init(data: "event 1".utf8Data),
        .init(data: "event 2".utf8Data),
        .init(data: "event 3".utf8Data)
    ]

    func testItCreatesPOSTRequest() throws {
        // Given
        let builder = RequestBuilder(
            customIntakeURL: nil,
            eventsFilter: .init(telemetry: TelemetryMock()),
            telemetry: NOPTelemetry()
        )

        // When
        let request = try builder.request(for: mockEvents, with: .mockAny(), execution: .mockAny())

        // Then
        XCTAssertEqual(request.httpMethod, "POST")
    }

    func testItSetsRUMIntakeURL() {
        // Given
        let builder = RequestBuilder(
            customIntakeURL: nil,
            eventsFilter: .init(telemetry: TelemetryMock()),
            telemetry: NOPTelemetry()
        )

        // When
        func url(for site: KubesenseSite) -> String {
            let request = try! builder.request(for: mockEvents, with: .mockWith(site: site), execution: .mockAny())
            return request.url!.absoluteStringWithoutQuery!
        }

        // Then
        XCTAssertEqual(url(for: .prod), "https://us2.kubesense.ai/rum/api/v1")
        XCTAssertEqual(url(for: .staging), "https://dev.kubesense.ai/rum/api/v1")
    }

    func testItUploadsToTheCoreCollectorEndpoint() throws {
        // Given
        let builder = RequestBuilder(
            customIntakeURL: nil,
            eventsFilter: .init(telemetry: TelemetryMock()),
            telemetry: NOPTelemetry()
        )
        let context: KubesenseContext = .mockWith(site: .prod, intakeEndpoint: URL(string: "https://collector.example.com")!)

        // When
        let request = try builder.request(for: mockEvents, with: context, execution: .mockAny())

        // Then — `kubesenseRumEndpoint` wins over the site, with the Android SDK's `/rum/api/v1` path
        XCTAssertEqual(request.url?.absoluteStringWithoutQuery, "https://collector.example.com/rum/api/v1")
        XCTAssertEqual(request.value(forHTTPHeaderField: "KUBESENSE-API-KEY"), context.clientToken)
        XCTAssertNotNil(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "ksource" })
    }

    func testItSetsCustomIntakeURL() throws {
        // Given
        let randomURL: URL = .mockRandom()
        let builder = RequestBuilder(
            customIntakeURL: randomURL,
            eventsFilter: .init(telemetry: TelemetryMock()),
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

    func testItSetsRUMQueryParameters() throws {
        let randomSource: String = .mockRandom(among: .alphanumerics)
        let randomVersion: String = .mockRandom(among: .decimalDigits)
        let randomService: String = .mockRandom(among: .alphanumerics)
        let randomEnv: String = .mockRandom(among: .alphanumerics)
        let randomSDKVersion: String = .mockRandom(among: .alphanumerics)
        let randomAttempt: UInt = .mockRandom()
        let randomStatus: Int = .mockRandom()

        // Given
        let builder = RequestBuilder(
            customIntakeURL: nil,
            eventsFilter: .init(telemetry: TelemetryMock()),
            telemetry: NOPTelemetry()
        )
        let context: KubesenseContext = .mockWith(
            service: randomService,
            env: randomEnv,
            version: randomVersion,
            source: randomSource,
            sdkVersion: randomSDKVersion
        )
        let execution: ExecutionContext = .mockWith(previousResponseCode: randomStatus, attempt: randomAttempt)

        // When
        let request = try builder.request(for: mockEvents, with: context, execution: execution)

        // Then
        let expextedQuery = "ksource=\(randomSource)&ktags=retry_count:\(randomAttempt),retry_after:\(randomStatus)"
        XCTAssertEqual(request.url?.query, expextedQuery)
    }

    func testItSetsRUMHTTPHeaders() throws {
        let randomApplicationName: String = .mockRandom(among: .alphanumerics)
        let randomVersion: String = .mockRandom(among: .decimalDigits)
        let randomService: String = .mockRandom(among: .alphanumerics)
        let randomEnv: String = .mockRandom(among: .alphanumerics)
        let randomSource: String = .mockRandom(among: .alphanumerics)
        let randomOrigin: String = .mockRandom(among: .alphanumerics)
        let randomSDKVersion: String = .mockRandom(among: .alphanumerics)
        let randomClientToken: String = .mockRandom()
        let randomDeviceName: String = .mockRandom()
        let randomDeviceOSName: String = .mockRandom()
        let randomDeviceOSVersion: String = .mockRandom()

        // Given
        let builder = RequestBuilder(
            customIntakeURL: nil,
            eventsFilter: .init(telemetry: TelemetryMock()),
            telemetry: NOPTelemetry()
        )
        let context: KubesenseContext = .mockWith(
            clientToken: randomClientToken,
            service: randomService,
            env: randomEnv,
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
        XCTAssertEqual(request.allHTTPHeaderFields?["Content-Encoding"], "deflate")
        XCTAssertEqual(request.allHTTPHeaderFields?["KUBESENSE-API-KEY"], randomClientToken)
        XCTAssertEqual(request.allHTTPHeaderFields?["KUBESENSE-EVP-ORIGIN"], randomOrigin)
        XCTAssertEqual(request.allHTTPHeaderFields?["KUBESENSE-EVP-ORIGIN-VERSION"], randomSDKVersion)
        XCTAssertEqual(request.allHTTPHeaderFields?["KUBESENSE-REQUEST-ID"]?.matches(regex: .uuidRegex), true)
    }

    func testItSetsHTTPBodyInExpectedFormat() throws {
        // Given
        let builder = RequestBuilder(
            customIntakeURL: nil,
            eventsFilter: .init(telemetry: TelemetryMock()),
            telemetry: NOPTelemetry()
        )

        // When
        let request = try builder.request(for: mockEvents, with: .mockAny(), execution: .mockAny())

        // Then
        let decompressed = zlib.decode(request.httpBody!)!
        let actual = String(data: decompressed, encoding: .utf8)
        let expected = """
        event 1
        event 2
        event 3
        """
        XCTAssertEqual(expected, actual, "It must separate each event with newline character")
    }

    func testItSetsNoRetryQueryParametersOnFirstRequest() throws {
        // Given
        let randomSource: String = .mockRandom(among: .alphanumerics)
        let builder = RequestBuilder(customIntakeURL: nil, eventsFilter: .init(telemetry: TelemetryMock()), telemetry: NOPTelemetry())
        let context: KubesenseContext = .mockWith(source: randomSource)
        let execution: ExecutionContext = .mockWith(previousResponseCode: nil, attempt: 0)

        // When
        let request = try builder.request(for: mockEvents, with: context, execution: execution)

        // Then
        XCTAssertEqual(request.url?.query, "ksource=\(randomSource)") // no ktags on first request
    }

    func testItSetsRetryQueryParametersOnNetworkErrorRetry() throws {
        // Given
        let randomSource: String = .mockRandom(among: .alphanumerics)
        let builder = RequestBuilder(customIntakeURL: nil, eventsFilter: .init(telemetry: TelemetryMock()), telemetry: NOPTelemetry())
        let context: KubesenseContext = .mockWith(source: randomSource)
        let execution: ExecutionContext = .mockWith(previousResponseCode: nil, attempt: 1) // network error retry has no response code

        // When
        let request = try builder.request(for: mockEvents, with: context, execution: execution)

        // Then
        XCTAssertEqual(request.url?.query, "ksource=\(randomSource)&ktags=retry_count:1") // no retry_after without response code
    }
}
