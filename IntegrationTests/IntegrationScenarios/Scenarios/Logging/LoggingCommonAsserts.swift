/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import HTTPServerMock
import TestUtilities
import XCTest

/// A set of common assertions for all Logging tests.
protocol LoggingCommonAsserts {
    func assertLogging(requests: [HTTPServerMock.Request], file: StaticString, line: UInt)
}

extension LoggingCommonAsserts {
    func assertLogging(
        requests: [HTTPServerMock.Request],
        file: StaticString = #file,
        line: UInt = #line
    ) {
        requests.forEach { request in
            XCTAssertEqual(request.httpMethod, "POST")

            // Example path here: `/36882784-420B-494F-910D-CBAC5897A309?ksource=ios`
            XCTAssertNotNil(request.path, file: file, line: line)
            XCTAssertNotNil(request.queryItems)
            XCTAssertEqual(request.queryItems!.count, 1)
            XCTAssertEqual(request.queryItems?.value(name: "ksource"), "ios", file: file, line: line)

            let ktags = request.queryItems?.ktags()
            XCTAssertNil(ktags, file: file, line: line)

            XCTAssertEqual(request.httpHeaders["Content-Type"], "application/json", file: file, line: line)
            XCTAssertEqual(request.httpHeaders["User-Agent"]?.matches(regex: userAgentRegex), true, file: file, line: line)
            XCTAssertEqual(request.httpHeaders["KUBESENSE-API-KEY"], "ui-tests-client-token", file: file, line: line)
            XCTAssertEqual(request.httpHeaders["KUBESENSE-EVP-ORIGIN"], "ios", file: file, line: line)
            XCTAssertEqual(request.httpHeaders["KUBESENSE-EVP-ORIGIN-VERSION"]?.matches(regex: semverRegex), true, file: file, line: line)
            XCTAssertEqual(request.httpHeaders["KUBESENSE-REQUEST-ID"]?.matches(regex: kubesenseRequestIDRegex), true, file: file, line: line)
        }
    }
}

extension LogMatcher {
    public class func from(requests: [HTTPServerMock.Request]) throws -> [LogMatcher] {
        return try requests
            .flatMap { request in try LogMatcher.fromArrayOfJSONObjectsData(request.httpBody) }
    }
}
