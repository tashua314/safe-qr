import Foundation
@testable import SafeQR
import XCTest

final class SafeBrowsingFailureTests: XCTestCase {
    private let url = "https://example.com/secret?token=dummy"
    private let list = PublicSuffixList(contents: "com\n")
    private var session: URLSession?
    private var requestCount = 0

    override func tearDown() {
        session?.invalidateAndCancel()
        session = nil
        FailureURLProtocol.handler = nil
        super.tearDown()
    }

    private func client(apiKey: String? = "test-key", enabled: Bool = true) -> SafeBrowsingAPIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FailureURLProtocol.self]
        let session = URLSession(configuration: config)
        self.session = session
        return SafeBrowsingAPIClient(
            configuration: .init(apiKey: { apiKey }, externalEnabled: { enabled }, suffixList: list),
            session: session
        )
    }

    private func respond(_ body: Any, status: Int = 200) {
        FailureURLProtocol.handler = { _ in
            self.requestCount += 1
            return try (status, JSONSerialization.data(withJSONObject: body, options: .fragmentsAllowed))
        }
    }

    private func check(_ client: SafeBrowsingAPIClient) throws -> SafeBrowsingAPIClient.CheckResult {
        let done = expectation(description: "照会結果")
        var received: SafeBrowsingAPIClient.CheckResult?
        client.checkURL(url) { result in received = result
            done.fulfill()
        }
        wait(for: [done], timeout: 3)
        return try XCTUnwrap(received)
    }

    private func matchedBody(details: Any) throws -> [String: Any] {
        let hash = try XCTUnwrap(SafeBrowsingURLHasher(suffixList: list).fullHashes(for: url).first)
        return ["cacheDuration": "60s", "fullHashes": [["fullHash": hash.base64EncodedString(), "fullHashDetails": details]]]
    }

    func testBatchPreservesMissingKeyForEveryURL() {
        let done = expectation(description: "一括照会")
        let urls = [url, "https://second.com/"]
        client(apiKey: nil).checkURLs(urls) { results in
            XCTAssertEqual(Set(results.keys), Set(urls))
            for result in results.values {
                guard case .failure(.apiKeyMissing) = result else { return XCTFail("失敗をsafeへ変換しない") }
            }
            done.fulfill()
        }
        wait(for: [done], timeout: 3)
        XCTAssertEqual(requestCount, 0)
    }

    func testDisabledIsNotAConfirmedSafeResult() throws {
        let result = try check(client(enabled: false))
        guard case .failure(.disabled) = result else { return XCTFail("OFFは未照会") }
        XCTAssertEqual(requestCount, 0)
    }

    func testBatchKeepsEachSuccessAndHTTPFailure() throws {
        let successURL = "https://first.com/a"
        let failedURL = "https://second.com/b"
        let successPrefixes = try Set(SafeBrowsingURLHasher(suffixList: list).fullHashes(for: successURL)
            .map { Data($0.prefix(4)).base64EncodedString() })
        FailureURLProtocol.handler = { request in
            self.requestCount += 1
            let requestURL = try XCTUnwrap(request.url)
            let items = try XCTUnwrap(URLComponents(url: requestURL, resolvingAgainstBaseURL: false)?.queryItems)
            let succeeds = items.contains { $0.name == "hashPrefixes" && successPrefixes.contains($0.value ?? "") }
            return (succeeds ? 200 : 403, Data("{\"cacheDuration\":\"60s\"}".utf8))
        }
        let done = expectation(description: "混在する一括結果")
        client().checkURLs([successURL, failedURL]) { results in
            guard case let .success(value)? = results[successURL] else { return XCTFail("成功結果が必要") }
            XCTAssertTrue(value.isURLSafe)
            guard case .failure(.apiError(403, _))? = results[failedURL] else { return XCTFail("403を保持する") }
            done.fulfill()
        }
        wait(for: [done], timeout: 3)
    }

    func testMalformedRootAndFullHashesAreFailures() throws {
        let bodies: [Any] = [
            [],
            NSNull(),
            "bad",
            [:],
            ["cacheDuration": "bad"],
            ["cacheDuration": "60s", "fullHashes": "bad"],
            ["cacheDuration": "60s", "fullHashes": NSNull()]
        ]
        for body in bodies {
            respond(body)
            guard case .failure(.parsingError) = try check(client()) else { return XCTFail("不正応答を安全へ変換しない") }
        }
    }

    func testAbsentAndEmptyFullHashesAreValidNoMatch() throws {
        for body in [["cacheDuration": "60s"], ["cacheDuration": "60s", "fullHashes": []]] as [[String: Any]] {
            respond(body)
            let result = try check(client()).get()
            XCTAssertTrue(result.isURLSafe)
            XCTAssertEqual(result.verificationStatus, .noMatch)
            XCTAssertEqual(result.safetyLevel, .safe)
        }
    }

    func testIncompleteMatchedDetailsAreParsingFailures() throws {
        let details: [Any] = [
            [],
            NSNull(),
            "bad",
            [["threatType": ""]],
            [["threatType": "MALWARE", "attributes": NSNull()]],
            [["threatType": "MALWARE", "attributes": "bad"]]
        ]
        for detail in details {
            try respond(matchedBody(details: detail))
            guard case .failure(.parsingError) = try check(client()) else { return XCTFail("脅威詳細の誤った型は失敗") }
        }
    }

    func testUnknownThreatAndAttributeAreUnconfirmed() throws {
        for detail in [["threatType": "FUTURE_THREAT"], ["threatType": "MALWARE", "attributes": ["FUTURE_ATTRIBUTE"]]] as [[String: Any]] {
            try respond(matchedBody(details: [detail]))
            let result = try check(client()).get()
            XCTAssertFalse(result.isURLSafe)
            XCTAssertNil(result.safetyLevel)
            XCTAssertEqual(result.verificationStatus, .unrecognizedThreats)
            XCTAssertTrue(result.detectedThreats.isEmpty)
        }
    }

    func testKnownDangerIsRetainedAlongsideUnknownDetails() throws {
        try respond(matchedBody(details: [["threatType": "MALWARE"], ["threatType": "FUTURE_THREAT"]]))
        let result = try check(client()).get()
        XCTAssertFalse(result.isURLSafe)
        XCTAssertEqual(result.verificationStatus, .unrecognizedThreats)
        XCTAssertEqual(result.safetyLevel, .danger)
        XCTAssertEqual(result.detectedThreats, [.malware])
    }

    func testMalformedResponseIsNotCached() throws {
        let service = client()
        respond(["cacheDuration": "60s", "fullHashes": NSNull()])
        guard case .failure = try check(service) else { return XCTFail("不正応答") }
        respond(["cacheDuration": "60s"])
        let result = try check(service).get()
        XCTAssertFalse(result.cacheHit)
        XCTAssertEqual(requestCount, 2)
    }

    func testTimeoutIsNotCachedOrSafe() throws {
        FailureURLProtocol.handler = { _ in throw URLError(.timedOut) }
        let service = client()
        guard case .failure(.timeout) = try check(service) else { return XCTFail("タイムアウトを保持する") }
        respond(["cacheDuration": "60s"])
        XCTAssertFalse(try check(service).get().cacheHit)
    }

    func testEnhancedEvaluatorKeepsFallbackDistinct() {
        let stub = FailureSafeBrowsingClient(result: .failure(.apiKeyMissing))
        let evaluator = EnhancedUrlRiskEvaluator(safeBrowsingClient: stub, externalEnabled: { true })
        evaluator.evaluateComplete(url: "https://example.com/") { result in
            XCTAssertEqual(result.evaluationMethod, .localFallback)
            XCTAssertNil(result.apiResult)
        }
        XCTAssertEqual(stub.calls, 1)
    }

    func testEnhancedEvaluatorKeepsKnownDangerAndUnknownState() {
        let api = SafeBrowsingAPIClient.SafeBrowsingResult(
            verificationStatus: .unrecognizedThreats,
            detectedThreats: [.malware],
            responseTime: 0,
            cacheHit: false
        )
        let stub = FailureSafeBrowsingClient(result: .success(api))
        EnhancedUrlRiskEvaluator(safeBrowsingClient: stub, externalEnabled: { true })
            .evaluateComplete(url: "https://example.com/") { result in
                XCTAssertEqual(result.evaluationMethod, .localFallback)
                XCTAssertEqual(result.finalSafetyLevel, .danger)
                XCTAssertEqual(result.apiResult?.verificationStatus, .unrecognizedThreats)
            }
    }
}

private final class FailureURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))?
    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let (status, data) = try XCTUnwrap(Self.handler)(request)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: XCTUnwrap(request.url),
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: [:]
            ))
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }

    override func stopLoading() {}
}

private final class FailureSafeBrowsingClient: SafeBrowsingAPIClientProtocol {
    let result: SafeBrowsingAPIClient.CheckResult
    var calls = 0
    init(result: SafeBrowsingAPIClient.CheckResult) {
        self.result = result
    }

    func checkURL(_: String, completion: @escaping (SafeBrowsingAPIClient.CheckResult) -> Void) {
        calls += 1
        completion(result)
    }

    func checkURLs(_ urls: [String], completion: @escaping ([String: SafeBrowsingAPIClient.CheckResult]) -> Void) {
        completion(Dictionary(urls.map { ($0, result) }, uniquingKeysWith: { first, _ in first }))
    }
}
