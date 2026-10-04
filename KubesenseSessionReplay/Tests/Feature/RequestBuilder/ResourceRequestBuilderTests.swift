/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

#if os(iOS)
import XCTest
import KubesenseInternal
@testable import KubesenseSessionReplay
@testable import TestUtilities

class ResourceRequestBuilderTests: XCTestCase {
    private let resources = [
        EnrichedResource.mockRandom(),
        EnrichedResource.mockRandom(),
        EnrichedResource.mockRandom()
    ]
    private var mockEvents: [Event] {
        return resources.map { .mockWith(data: try! JSONEncoder().encode($0)) }
    }

    func testItCreatesPOSTRequest() throws {
        // Given
        let builder = ResourceRequestBuilder(customUploadURL: nil, telemetry: TelemetryMock())

        // When
        let request = try builder.request(for: mockEvents, with: .mockRandom(), execution: .mockAny())

        // Then
        XCTAssertEqual(request.httpMethod, "POST")
    }

    func testItSetsIntakeURL() {
        // Given
        let builder = ResourceRequestBuilder(customUploadURL: nil, telemetry: TelemetryMock())

        // When
        func url(for site: KubesenseSite) throws -> String {
            let request = try builder.request(for: mockEvents, with: .mockWith(site: site), execution: .mockAny())
            return request.url!.absoluteStringWithoutQuery!
        }

        // Then
        XCTAssertEqual(try url(for: .prod), "https://us2.kubesense.ai/rum/api/v1/replay")
        XCTAssertEqual(try url(for: .staging), "https://dev.kubesense.ai/rum/api/v1/replay")
    }

    func testItSetsCustomIntakeURL() {
        // Given
        let randomURL: URL = .mockRandom()
        let builder = ResourceRequestBuilder(customUploadURL: randomURL, telemetry: TelemetryMock())

        // When
        func url(for site: KubesenseSite) throws -> String {
            let request = try builder.request(for: mockEvents, with: .mockWith(site: site), execution: .mockAny())
            return request.url!.absoluteStringWithoutQuery!
        }

        // Then
        let expectedURL = randomURL.absoluteStringWithoutQuery
        XCTAssertEqual(try url(for: .prod), expectedURL)
        XCTAssertEqual(try url(for: .staging), expectedURL)
    }

    func testItSetsQueryParameters() throws {
        // Given
        let builder = ResourceRequestBuilder(customUploadURL: nil, telemetry: TelemetryMock())

        // When
        let request = try builder.request(for: mockEvents, with: .mockRandom(), execution: .init(previousResponseCode: nil, attempt: 0))

        // Then
        XCTAssertNil(request.url!.query)
    }

    func testItSetsHTTPHeaders() throws {
        let randomApplicationName: String = .mockRandom(among: .alphanumerics)
        let randomVersion: String = .mockRandom(among: .decimalDigits)
        let randomSource: String = .mockRandom(among: .alphanumerics)
        let randomSDKVersion: String = .mockRandom(among: .alphanumerics)
        let randomClientToken: String = .mockRandom()
        let randomDeviceName: String = .mockRandom()
        let randomDeviceOSName: String = .mockRandom()
        let randomDeviceOSVersion: String = .mockRandom()

        // Given
        let builder = ResourceRequestBuilder(customUploadURL: nil, telemetry: TelemetryMock())
        let context: KubesenseContext = .mockWith(
            clientToken: randomClientToken,
            version: randomVersion,
            source: randomSource,
            sdkVersion: randomSDKVersion,
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
        let contentType = try XCTUnwrap(request.allHTTPHeaderFields?["Content-Type"])
        XCTAssertTrue(contentType.matches(regex: #"multipart\/form-data; boundary=([0-9A-Fa-f]{8}(-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12})"#))
        XCTAssertEqual(
            request.allHTTPHeaderFields?["User-Agent"],
            """
            \(randomApplicationName)/\(randomVersion) CFNetwork (\(randomDeviceName); \(randomDeviceOSName)/\(randomDeviceOSVersion))
            """
        )
        XCTAssertEqual(request.allHTTPHeaderFields?["KUBESENSE-API-KEY"], randomClientToken)
        XCTAssertEqual(request.allHTTPHeaderFields?["KUBESENSE-EVP-ORIGIN"], randomSource)
        XCTAssertEqual(request.allHTTPHeaderFields?["KUBESENSE-EVP-ORIGIN-VERSION"], randomSDKVersion)
        XCTAssertNotNil(request.allHTTPHeaderFields?["Content-Encoding"], "It must us no compression, because multipart file is compressed separately")
        XCTAssertEqual(request.allHTTPHeaderFields?["KUBESENSE-REQUEST-ID"]?.matches(regex: .uuidRegex), true)
    }

    func testItSetsHTTPBodyInExpectedFormat() throws {
        // Given
        let multipartSpy = MultipartBuilderSpy()
        let builder = ResourceRequestBuilder(customUploadURL: nil, telemetry: TelemetryMock(), multipartBuilder: multipartSpy)

        // When
        let request = try builder.request(for: mockEvents, with: .mockRandom(), execution: .mockAny())

        // Then
        let contentType = try XCTUnwrap(request.allHTTPHeaderFields?["Content-Type"])
        XCTAssertTrue(contentType.matches(regex: "multipart/form-data; boundary=\(multipartSpy.boundary)"))

        for i in 0..<resources.count {
            XCTAssertNotNil(multipartSpy.formFiles[i].filename)
            XCTAssertGreaterThan(multipartSpy.formFiles[i].data.count, 0)
            XCTAssertEqual(multipartSpy.formFiles[i].mimeType, resources[i].mimeType)
        }

        XCTAssertEqual(multipartSpy.formFiles.last?.filename, "blob")
        XCTAssertGreaterThan(multipartSpy.formFiles.last?.data.count ?? 0, 0)
        XCTAssertEqual(multipartSpy.formFiles.last?.mimeType, "application/json")
    }

    func testWhenBatchDataIsMalformed_itThrows() {
        // Given
        let builder = ResourceRequestBuilder(customUploadURL: nil, telemetry: TelemetryMock())

        // When, Then
        XCTAssertThrowsError(try builder.request(for: [.mockWith(data: "abc".utf8Data)], with: .mockRandom(), execution: .mockAny()))
    }

    func testItSetsRetryQueryParameters() throws {
        // Given
        let randomAttempt: UInt = .mockRandom(min: 1, max: 10)
        let randomStatus: Int = .mockRandom()
        let builder = ResourceRequestBuilder(customUploadURL: nil, telemetry: TelemetryMock())
        let execution: ExecutionContext = .mockWith(previousResponseCode: randomStatus, attempt: randomAttempt)

        // When
        let request = try builder.request(for: mockEvents, with: .mockRandom(), execution: execution)

        // Then
        XCTAssertEqual(request.url!.query, "ktags=retry_count:\(randomAttempt),retry_after:\(randomStatus)")
    }

    func testItSetsRetryQueryParametersOnNetworkErrorRetry() throws {
        // Given
        let builder = ResourceRequestBuilder(customUploadURL: nil, telemetry: TelemetryMock())
        let execution: ExecutionContext = .mockWith(previousResponseCode: nil, attempt: 1) // network error retry has no response code

        // When
        let request = try builder.request(for: mockEvents, with: .mockRandom(), execution: execution)

        // Then
        XCTAssertEqual(request.url!.query, "ktags=retry_count:1") // no retry_after without response code
    }
}
#endif
