import Foundation
@testable import SafeQR
import XCTest

final class SafeBrowsingPrivacyTests: XCTestCase {
    private let list = PublicSuffixList(contents: "com\nco.uk\n")
    private let input = "https://private.example.com/path_marker?token=query_marker#fragment_marker"
    private var session: URLSession?
    private var requests = [URLRequest]()

    override func tearDown() {
        session?.invalidateAndCancel()
        session = nil
        PrivacyURLProtocol.handler = nil
        requests.removeAll()
        super.tearDown()
    }

    private func makeClient(enabled: Bool = true, now: @escaping () -> Date = Date.init) -> SafeBrowsingAPIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PrivacyURLProtocol.self]
        let session = URLSession(configuration: config)
        self.session = session
        return SafeBrowsingAPIClient(
            configuration: .init(apiKey: { "test-key" }, externalEnabled: { enabled }, suffixList: list, now: now),
            session: session
        )
    }

    private func check(_ client: SafeBrowsingAPIClient, url: String) throws -> SafeBrowsingAPIClient.SafeBrowsingResult {
        let done = expectation(description: "外部照会の完了")
        var received: Result<SafeBrowsingAPIClient.SafeBrowsingResult, SafeBrowsingAPIClient.SafeBrowsingError>?
        client.checkURL(url) { result in received = result
            done.fulfill()
        }
        wait(for: [done], timeout: 3)
        return try XCTUnwrap(received).get()
    }

    private func respond(_ body: [String: Any]) {
        PrivacyURLProtocol.handler = { request in
            self.requests.append(request)
            return try JSONSerialization.data(withJSONObject: body)
        }
    }

    func testRequestsContainOnlyFourByteHashPrefixes() throws {
        respond(["cacheDuration": "60s"])
        let client = makeClient()
        XCTAssertTrue(try check(client, url: input).isURLSafe)
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertNil(request.httpBody)
        let url = try XCTUnwrap(request.url)
        XCTAssertEqual(url.host, "safebrowsing.googleapis.com")
        XCTAssertEqual(url.path, "/v5/hashes:search")
        for marker in [input, "private.example.com", "path_marker", "query_marker", "fragment_marker"] {
            XCTAssertFalse(url.absoluteString.contains(marker))
            XCTAssertFalse(String(describing: request.allHTTPHeaderFields).contains(marker))
        }
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(Set(items.map(\.name)), ["key", "hashPrefixes"])
        let sent = try items.filter { $0.name == "hashPrefixes" }.map { try XCTUnwrap(Data(base64Encoded: XCTUnwrap($0.value))) }
        XCTAssertTrue(sent.allSatisfy { $0.count == 4 })
        let expected = try Set(SafeBrowsingURLHasher(suffixList: list).fullHashes(for: input).map { Data($0.prefix(4)) })
        XCTAssertEqual(Set(sent), expected)
    }

    func testBase64PlusSurvivesFormQueryDecoding() throws {
        respond(["cacheDuration": "60s"])
        let url = "https://example.com/11"
        _ = try check(makeClient(), url: url)
        let requestURL = try XCTUnwrap(requests.first?.url)
        let query = try XCTUnwrap(URLComponents(url: requestURL, resolvingAgainstBaseURL: false)?.percentEncodedQuery)
        XCTAssertFalse(query.contains("+"))
        let sent = try query.split(separator: "&").filter { $0.hasPrefix("hashPrefixes=") }.map { item in
            let encoded = String(item.dropFirst("hashPrefixes=".count)).replacingOccurrences(of: "+", with: " ")
            let decoded = try XCTUnwrap(encoded.removingPercentEncoding)
            return try XCTUnwrap(Data(base64Encoded: decoded))
        }
        let expected = try Set(SafeBrowsingURLHasher(suffixList: list).fullHashes(for: url).map { Data($0.prefix(4)) })
        XCTAssertEqual(Set(sent), expected)
        XCTAssertTrue(query.contains("%2B"), "plusを含む既知の候補で検証する")
    }

    func testPotentiallyHarmfulApplicationRemainsDangerInV5() throws {
        let hash = try XCTUnwrap(SafeBrowsingURLHasher(suffixList: list).fullHashes(for: input).first)
        respond(["cacheDuration": "60s", "fullHashes": [["fullHash": hash.base64EncodedString(), "fullHashDetails": [
            ["threatType": "POTENTIALLY_HARMFUL_APPLICATION"]
        ]]]])
        let result = try check(makeClient(), url: input)
        XCTAssertFalse(result.isURLSafe)
        XCTAssertEqual(result.safetyLevel, .danger)
        XCTAssertEqual(result.detectedThreats, [.potentiallyHarmfulApplication])
    }

    func testExternalOffMakesNoRequest() throws {
        respond(["cacheDuration": "60s"])
        XCTAssertThrowsError(try check(makeClient(enabled: false), url: input)) { error in
            guard case SafeBrowsingAPIClient.SafeBrowsingError.disabled = error else { return XCTFail("無効を成功へ変換しない") }
        }
        XCTAssertTrue(requests.isEmpty)
    }

    func testPrefixCollisionDoesNotBecomeAThreat() throws {
        let hashes = try SafeBrowsingURLHasher(suffixList: list).fullHashes(for: input)
        var collision = try XCTUnwrap(hashes.first)
        collision[31] ^= 1
        respond([
            "cacheDuration": "60s",
            "fullHashes": [["fullHash": collision.base64EncodedString(), "fullHashDetails": [["threatType": "MALWARE"]]]]
        ])
        XCTAssertTrue(try check(makeClient(), url: input).isURLSafe)
    }

    func testFullHashMatchIsAppliedLocally() throws {
        let hash = try XCTUnwrap(SafeBrowsingURLHasher(suffixList: list).fullHashes(for: input).first)
        respond([
            "cacheDuration": "60s",
            "fullHashes": [["fullHash": hash.base64EncodedString(), "fullHashDetails": [["threatType": "SOCIAL_ENGINEERING"]]]]
        ])
        let result = try check(makeClient(), url: input)
        XCTAssertFalse(result.isURLSafe)
        XCTAssertEqual(result.safetyLevel, .danger)
        XCTAssertEqual(result.detectedThreats, [.socialEngineering])
    }

    func testServerTTLAndNegativeCache() throws {
        var now = Date(timeIntervalSince1970: 1000)
        respond(["cacheDuration": "1.5s", "fullHashes": []])
        let client = makeClient(now: { now })
        XCTAssertFalse(try check(client, url: input).cacheHit)
        XCTAssertTrue(try check(client, url: input).cacheHit)
        XCTAssertEqual(requests.count, 1)
        now = now.addingTimeInterval(1.5)
        XCTAssertFalse(try check(client, url: input).cacheHit)
        XCTAssertEqual(requests.count, 2)
    }

    func testPositiveCacheRefreshesAtThirtyMinutesWhileNegativePrefixesRemainCached() throws {
        var now = Date(timeIntervalSince1970: 1000)
        let hash = try XCTUnwrap(SafeBrowsingURLHasher(suffixList: list).fullHashes(for: input).first)
        respond(["cacheDuration": "3600s", "fullHashes": [[
            "fullHash": hash.base64EncodedString(), "fullHashDetails": [["threatType": "MALWARE"]]
        ]]])
        let client = makeClient(now: { now })
        XCTAssertEqual(try check(client, url: input).safetyLevel, .danger)
        now = now.addingTimeInterval(1799)
        XCTAssertTrue(try check(client, url: input).cacheHit)
        XCTAssertEqual(requests.count, 1)
        now = now.addingTimeInterval(1)
        respond(["cacheDuration": "3600s"])
        XCTAssertTrue(try check(client, url: input).isURLSafe, "古い危険情報で警告し続けない")
        XCTAssertEqual(requests.count, 2)
        let request = try XCTUnwrap(requests.last?.url)
        let sent = try XCTUnwrap(URLComponents(url: request, resolvingAgainstBaseURL: false)?.queryItems)
            .filter { $0.name == "hashPrefixes" }.compactMap(\.value)
        XCTAssertEqual(sent, [Data(hash.prefix(4)).base64EncodedString()], "陰性prefixは3600秒のTTLを保つ")
    }

    func testPositiveCacheDoesNotExtendShorterServerTTL() throws {
        var now = Date(timeIntervalSince1970: 1000)
        let hash = try XCTUnwrap(SafeBrowsingURLHasher(suffixList: list).fullHashes(for: input).first)
        respond(["cacheDuration": "10s", "fullHashes": [[
            "fullHash": hash.base64EncodedString(), "fullHashDetails": [["threatType": "MALWARE"]]
        ]]])
        let client = makeClient(now: { now })
        _ = try check(client, url: input)
        now = now.addingTimeInterval(10)
        XCTAssertFalse(try check(client, url: input).cacheHit)
        XCTAssertEqual(requests.count, 2)
    }

    func testCachedPrefixesAreNotRequestedAgainForAnotherPath() throws {
        respond(["cacheDuration": "60s"])
        let client = makeClient()
        _ = try check(client, url: "https://example.com/first")
        _ = try check(client, url: "https://example.com/second")
        XCTAssertEqual(requests.count, 2)
        let second = try XCTUnwrap(requests.last?.url)
        let prefixes = try XCTUnwrap(URLComponents(url: second, resolvingAgainstBaseURL: false)?.queryItems)
            .filter { $0.name == "hashPrefixes" }
        XCTAssertEqual(prefixes.count, 1, "rootのprefixはキャッシュで照合する")
    }

    func testCanaryAndFrameOnlyDoNotApplyToTopLevel() throws {
        let hash = try XCTUnwrap(SafeBrowsingURLHasher(suffixList: list).fullHashes(for: input).first)
        respond(["cacheDuration": "60s", "fullHashes": [["fullHash": hash.base64EncodedString(), "fullHashDetails": [
            ["threatType": "MALWARE", "attributes": ["CANARY"]], ["threatType": "MALWARE", "attributes": ["FRAME_ONLY"]]
        ]]]])
        XCTAssertTrue(try check(makeClient(), url: input).isURLSafe)
    }
}

private final class PrivacyURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> Data)?
    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let data = try XCTUnwrap(Self.handler)(request)
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            ))
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }

    override func stopLoading() {}
}
