/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Kubesense addition to the fork of dd-sdk-ios, see docs/UPSTREAM_SYNC.md.
 */

import XCTest
@testable import KubesenseShop

final class CommerceRepositoryTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.response = nil
        super.tearDown()
    }

    private func repository() -> CommerceRepository {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return CommerceRepository(baseURL: "https://shop.example.com/", session: URLSession(configuration: configuration))
    }

    func testNoBaseURLServesTheOfflineCatalog() async {
        let catalog = await CommerceRepository(baseURL: "").loadProducts(page: 1)

        XCTAssertEqual(catalog.origin, .fallback)
        XCTAssertEqual(catalog.total, 104)
        XCTAssertEqual(FallbackCatalog.products.count, 104)
        XCTAssertEqual(catalog.products.count, CommerceRepository.pageSize)
        XCTAssertTrue(catalog.hasMore)
    }

    func testOfflinePagingStopsAtTheLastPage() {
        let last = FallbackCatalog.page(6, limit: 20, message: "")

        XCTAssertEqual(last.products.map(\.id), Array(101...104))
        XCTAssertFalse(last.hasMore)
        XCTAssertEqual(FallbackCatalog.products[8].title, "Terra headphones · Edition 2")
    }

    func testLiveResponseFillsAMissingThumbnail() async {
        StubURLProtocol.response = (200, #"{"products":[{"id":42,"title":"Live item","description":"From API","price":12.5,"category":"Test","rating":4.2,"thumbnail":null}]}"#)

        let catalog = await repository().loadProducts(page: 1)

        XCTAssertEqual(catalog.origin, .live)
        XCTAssertEqual(catalog.products.map(\.id), [42])
        XCTAssertEqual(catalog.products.first?.thumbnail, ProductImages.forProduct(42))
    }

    func testServerErrorFallsBackWithTheStatus() async {
        StubURLProtocol.response = (503, "{}")

        let catalog = await repository().loadProducts(page: 1)

        XCTAssertEqual(catalog.origin, .fallback)
        XCTAssertTrue(catalog.message?.contains("HTTP 503") == true)
    }

    func testLoginReportsTheServerError() async {
        StubURLProtocol.response = (401, #"{"error":"Email or password is incorrect"}"#)

        let result = await repository().login(email: "a@b.c", password: "nope")

        XCTAssertEqual(result.failureMessage, "Email or password is incorrect")
    }
}

private extension Result where Failure == ShopError {
    var failureMessage: String? {
        if case .failure(let error) = self { return error.message }
        return nil
    }
}

final class StubURLProtocol: URLProtocol {
    static var response: (status: Int, body: String)?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let (status, body) = Self.response, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
