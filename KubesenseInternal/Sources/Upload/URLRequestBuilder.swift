/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import Foundation

/// Builds `URLRequest` for sending data to Kubesense.
public struct URLRequestBuilder {
    public enum QueryItem {
        /// `ksource={source}` query item
        case ksource(source: String)
        /// `ktags={tag1},{tag2},...` query item
        case ktags(tags: [String])
    }

    public struct HTTPHeader {
        public static let contentTypeHeaderField = "Content-Type"
        public static let contentEncodingHeaderField = "Content-Encoding"
        public static let userAgentHeaderField = "User-Agent"
        public static let kubesenseAPIKeyHeaderField = "KUBESENSE-API-KEY"
        public static let kubesenseClientTokenHeaderField = "DD-CLIENT-TOKEN"
        public static let kubesenseEVPOriginHeaderField = "KUBESENSE-EVP-ORIGIN"
        public static let kubesenseEVPOriginVersionHeaderField = "KUBESENSE-EVP-ORIGIN-VERSION"
        public static let kubesenseRequestIDHeaderField = "KUBESENSE-REQUEST-ID"
        public static let kubesenseIdempotencyKeyHeaderField = "KUBESENSE-IDEMPOTENCY-KEY"

        public enum ContentType {
            case applicationJSON
            case textPlainUTF8
            case multipartFormData(boundary: String)

            public var toString: String {
                switch self {
                case .applicationJSON: return "application/json"
                case .textPlainUTF8: return "text/plain;charset=UTF-8"
                case .multipartFormData(let boundary): return "multipart/form-data; boundary=\(boundary)"
                }
            }
        }

        let field: String
        let value: () -> String

        public init(field: String, value: @escaping () -> String) {
            self.field = field
            self.value = value
        }

        // MARK: - Standard Headers

        /// Standard "Content-Type" header.
        public static func contentTypeHeader(contentType: ContentType) -> HTTPHeader {
            return HTTPHeader(field: contentTypeHeaderField, value: { contentType.toString })
        }

        /// Standard "User-Agent" header.
        public static func userAgentHeader(
            appName: String,
            appVersion: String,
            device: DeviceInfo,
            os: OperatingSystem
        ) -> HTTPHeader {
            var sanitizedAppName = appName

            if let regex = try? NSRegularExpression(pattern: "[^a-zA-Z0-9 -]+") {
                sanitizedAppName = regex.stringByReplacingMatches(
                    in: appName,
                    range: NSRange(appName.startIndex..<appName.endIndex, in: appName),
                    withTemplate: ""
                )
                .trimmingCharacters(in: .whitespacesAndNewlines)
            }

            let agent = "\(sanitizedAppName)/\(appVersion) CFNetwork (\(device.name); \(os.name)/\(os.version))"
            return HTTPHeader(field: userAgentHeaderField, value: { agent })
        }

        // MARK: - Kubesense Headers

        /// Kubesense request authentication header.
        public static func kubesenseAPIKeyHeader(clientToken: String) -> HTTPHeader {
            return HTTPHeader(field: kubesenseAPIKeyHeaderField, value: { clientToken })
        }

        /// Kubesense client token authentication header.
        public static func kubesenseClientTokenHeader(clientToken: String) -> HTTPHeader {
            return HTTPHeader(field: kubesenseClientTokenHeaderField, value: { clientToken })
        }

        /// An observability and troubleshooting Kubesense header for tracking the origin which is sending the request.
        public static func kubesenseEVPOriginHeader(source: String) -> HTTPHeader {
            return HTTPHeader(field: kubesenseEVPOriginHeaderField, value: { source })
        }

        /// An observability and troubleshooting Kubesense header for tracking the origin which is sending the request.
        public static func kubesenseEVPOriginVersionHeader(sdkVersion: String) -> HTTPHeader {
            return HTTPHeader(field: kubesenseEVPOriginVersionHeaderField, value: { sdkVersion })
        }

        /// An optional Kubesense header for debugging Intake requests by their ID.
        public static func kubesenseRequestIDHeader() -> HTTPHeader {
            return HTTPHeader(field: kubesenseRequestIDHeaderField, value: { UUID().uuidString })
        }

        /// An optional Kubesense header for ensuring idempotent requests.
        /// - Parameter key: The idempotency key.
        /// - Returns: Header with the idempotency key.
        public static func kubesenseIdempotencyKeyHeader(key: String) -> HTTPHeader {
            return HTTPHeader(field: kubesenseIdempotencyKeyHeaderField, value: { key })
        }
    }

    /// Marks a request as originating from the SDK itself using a local-only `URLProtocol` property
    /// (never sent over the wire), so it can be recognized as internal by automatic `URLSession`
    /// instrumentation without requiring Kubesense intake credentials on the request - useful for SDK
    /// requests (e.g. Remote Configuration fetches) that must reach third-party or customer-controlled
    /// endpoints unmodified.
    public static func markAsInternal(_ request: inout URLRequest) {
        guard let mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            return
        }
        URLProtocol.setProperty(true, forKey: isInternalRequestPropertyKey, in: mutableRequest)
        request = mutableRequest as URLRequest
    }

    /// Checks whether a request was marked internal via `markAsInternal(_:)`.
    public static func isMarkedInternal(_ request: URLRequest) -> Bool {
        return URLProtocol.property(forKey: isInternalRequestPropertyKey, in: request) != nil
    }

    private static let isInternalRequestPropertyKey = "ai.kubesense.is-internal-request"
    /// Upload `URL`.
    private let url: URL
    /// HTTP headers.
    private let headers: [HTTPHeader]
    /// Telemetry interface.
    private let telemetry: Telemetry

    // MARK: - Initialization

    public init(
        url: URL,
        queryItems: [QueryItem],
        headers: [HTTPHeader],
        telemetry: Telemetry = NOPTelemetry()
    ) {
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)

        if !queryItems.isEmpty {
            urlComponents?.queryItems = queryItems.map { .init($0) }
        }

        self.url = urlComponents?.url ?? url
        self.headers = headers
        self.telemetry = telemetry
    }

    /// Creates `URLRequest` for uploading given `body` to Kubesense.
    ///
    /// - Parameter body: HTTP body to be attached to request
    /// - Parameter compress: if `body` should be compressed into ZLIB Compressed Data Format (IETF RFC 1950)
    /// - Returns: the `URLRequest` object.
    public func uploadRequest(with body: Data, compress: Bool = true) -> URLRequest {
        var request = URLRequest(url: url)
        var headers: [String: String] = [:]
        self.headers.forEach { headers[$0.field] = $0.value() }
        request.httpMethod = "POST"

        if compress, let deflatedBody = Deflate.encode(body) {
            headers[HTTPHeader.contentEncodingHeaderField] = "deflate"
            request.httpBody = deflatedBody
        } else {
            request.httpBody = body
            if compress {
                telemetry.debug(
                    """
                    Failed to compress request payload
                    - url: \(url)
                    - uncompressed-size: \(body.count)
                    """
                )
            }
        }

        headers.forEach { field, value in
            request.setValue(value, forHTTPHeaderField: field)
        }
        return request
    }
}

extension URLQueryItem {
    init(_ query: URLRequestBuilder.QueryItem) {
        switch query {
        case .ksource(let source):
            self = URLQueryItem(name: "ksource", value: source)
        case .ktags(let tags):
            self = URLQueryItem(name: "ktags", value: tags.joined(separator: ","))
        }
    }
}
