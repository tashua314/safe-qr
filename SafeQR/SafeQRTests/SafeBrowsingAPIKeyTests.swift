import Foundation
@testable import SafeQR
import XCTest

final class SafeBrowsingAPIKeyTests: XCTestCase {
    private let invalidValues: [String?] = [
        nil, "", " \n ", "$(SAFE_BROWSING_API_KEY)", "${SAFE_BROWSING_API_KEY}",
        "YOUR_API_KEY_HERE", "YOUR_DEV_API_KEY_HERE", "YOUR_PROD_API_KEY_HERE", "your_future_key",
        "[要設定]", "<API_KEY>", "has space", "line\nbreak"
    ]

    override func tearDown() {
        KeyConfigurationURLProtocol.status = 200
        KeyConfigurationURLProtocol.requestCount = 0
        super.tearDown()
    }

    func testMissingAndPlaceholderValuesAreRejected() {
        for value in invalidValues {
            XCTAssertNil(SafeBrowsingAPIKey.validated(value))
        }
    }

    func testConfiguredValueIsPreservedWithoutLogging() {
        XCTAssertEqual(SafeBrowsingAPIKey.validated("  fixture-key_123 \n"), "fixture-key_123")
    }

    func testInvalidConfigurationNeverStartsRequest() {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        for value in invalidValues {
            let done = expectation(description: "設定未完了")
            let client = makeClient(key: value, session: session)
            client.checkURL("https://example.com/") { result in
                guard case .failure(.apiKeyMissing) = result else { return XCTFail("不正設定は照会前に失敗する") }
                done.fulfill()
            }
            wait(for: [done], timeout: 2)
        }
        XCTAssertEqual(KeyConfigurationURLProtocol.requestCount, 0)
    }

    func testConfiguredKeyPreservesAuthenticationSuccessAndFailurePaths() {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        for status in [200, 403] {
            KeyConfigurationURLProtocol.status = status
            let done = expectation(description: "認証応答経路")
            makeClient(key: "fixture-key", session: session).checkURL("https://example.com/") { result in
                if status == 200 {
                    guard case let .success(value) = result else { return XCTFail("正常な該当なし応答を保持する") }
                    XCTAssertTrue(value.isURLSafe)
                } else {
                    guard case .failure(.apiError(403, _)) = result else { return XCTFail("認証拒否を保持する") }
                }
                done.fulfill()
            }
            wait(for: [done], timeout: 2)
        }
        XCTAssertEqual(KeyConfigurationURLProtocol.requestCount, 2)
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [KeyConfigurationURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func makeClient(key: String?, session: URLSession) -> SafeBrowsingAPIClient {
        SafeBrowsingAPIClient(
            configuration: .init(apiKey: { key }, externalEnabled: { true }, suffixList: PublicSuffixList(contents: "com\n")),
            session: session
        )
    }
}

private class KeyConfigurationURLProtocol: URLProtocol {
    static var status = 200
    static var requestCount = 0
    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.requestCount += 1
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: Self.status, httpVersion: nil, headerFields: nil) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{\"cacheDuration\":\"60s\"}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
