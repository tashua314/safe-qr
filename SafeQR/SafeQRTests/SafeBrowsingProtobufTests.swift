import Foundation
@testable import SafeQR
import XCTest

final class SafeBrowsingProtobufTests: XCTestCase {
    private let url = "https://example.com/private?token=fixture"
    private let list = PublicSuffixList(contents: "com\n")
    private var session: URLSession?
    private var calls = 0

    override func tearDown() {
        session?.invalidateAndCancel()
        session = nil
        ProtobufURLProtocol.handler = nil
        super.tearDown()
    }

    func testRealPublicPhishingResponseFixture() throws {
        // 2026-10-15、Google公開テストURL /s/phishing.html の実API応答。キーや利用者URLは含まない。
        let data = try XCTUnwrap(Data(base64Encoded: "CiYKIO+9TDq0TzJ+sTypQq18fwq0fsJgpNC4BRaEoBsu81IgEgIIAhIDCKwC"))
        let response = try SafeBrowsingProtobufDecoder.decode(data)
        XCTAssertEqual(response.cacheDuration, "300.000000000s")
        XCTAssertEqual(response.fullHashes.count, 1)
        XCTAssertEqual(response.fullHashes.first?.fullHash.base64EncodedString(), "771MOrRPMn6xPKlCrXx/CrR+wmCk0LgFFoSgGy7zUiA=")
        XCTAssertEqual(response.fullHashes.first?.fullHashDetails.first?.threatType, "SOCIAL_ENGINEERING")
    }

    func testRealNoMatchResponseAndFractionalTTL() throws {
        let data = try XCTUnwrap(Data(base64Encoded: "EgMIrAI="))
        XCTAssertTrue(try SafeBrowsingProtobufDecoder.decode(data).fullHashes.isEmpty)
        let fractional = message(2, scalar(1, 1) + scalar(2, 500_000_000))
        XCTAssertEqual(try SafeBrowsingProtobufDecoder.decode(fractional).cacheDuration, "1.500000000s")
    }

    func testMissingDurationFailsAndExplicitZeroIsValid() throws {
        XCTAssertThrowsError(try SafeBrowsingProtobufDecoder.decode(Data()))
        XCTAssertEqual(try SafeBrowsingProtobufDecoder.decode(message(2, Data())).cacheDuration, "0.000000000s")
    }

    func testDurationBoundsAndNegativeSignedValuesFail() throws {
        for data in [scalar(1, 315_576_000_001), scalar(1, .max), scalar(2, 1_000_000_000), scalar(2, .max)] {
            XCTAssertThrowsError(try SafeBrowsingProtobufDecoder.decode(message(2, data)))
        }
        let maximum = message(2, scalar(1, 315_576_000_000) + scalar(2, 999_999_999))
        XCTAssertEqual(try SafeBrowsingProtobufDecoder.decode(maximum).cacheDuration, "315576000000.999999999s")
    }

    func testMalformedTagsLengthsVarintsAndKnownWireTypesFail() {
        let invalid: [Data] = [
            Data([0]), Data([0x80]), Data(repeating: 0xFF, count: 10), Data([0x12, 0x02, 0x08]),
            Data([0x12]) + Data(repeating: 0xFF, count: 9) + Data([0x02]),
            Data([0x10, 0x00]), message(2, message(1, Data())),
            message(2, scalar(1, 60)) + Data([0x1B]),
            message(2, scalar(1, 60)) + Data([0x19, 0x01]),
            message(2, scalar(1, 60)) + Data([0x1D, 0x01])
        ]
        for data in invalid {
            XCTAssertThrowsError(try SafeBrowsingProtobufDecoder.decode(data))
        }
    }

    func testUnknownFieldsOfSupportedWireTypesAreSkipped() throws {
        let unknown = scalar(3, 9) + message(4, Data([1, 2])) + Data([0x29]) + Data(repeating: 0, count: 8)
            + Data([0x35]) + Data(repeating: 0, count: 4)
        let data = unknown + message(2, scalar(1, 60) + unknown)
        XCTAssertEqual(try SafeBrowsingProtobufDecoder.decode(data).cacheDuration, "60.000000000s")
    }

    func testOversizedAndExcessiveFieldInputsAreRejected() {
        XCTAssertThrowsError(try SafeBrowsingProtobufDecoder.decode(Data(repeating: 0, count: 8 * 1024 * 1024 + 1)))
        var fields = Data()
        for _ in 0 ..< 100_001 {
            fields.append(contentsOf: [0x18, 0])
        }
        fields += message(2, Data())
        XCTAssertThrowsError(try SafeBrowsingProtobufDecoder.decode(fields))
    }

    func testProtobufThreatIsAppliedAndCachedByAPIClient() throws {
        let service = makeClient()
        try respond(body(details: [scalar(1, 2)]))
        let result = try check(service).get()
        XCTAssertEqual(result.safetyLevel, .danger)
        XCTAssertEqual(result.detectedThreats, [.socialEngineering])
        XCTAssertTrue(try check(service).get().cacheHit)
        XCTAssertEqual(calls, 1)
    }

    func testProtobufNoMatchIsValidatedAndCached() throws {
        let service = makeClient()
        respond(message(2, scalar(1, 60)))
        XCTAssertTrue(try check(service).get().isURLSafe)
        XCTAssertTrue(try check(service).get().cacheHit)
        XCTAssertEqual(calls, 1)
    }

    func testUnknownAndUnspecifiedThreatsRemainUnconfirmed() throws {
        for threat: UInt64 in [0, 99, .max] {
            try respond(body(details: [scalar(1, threat)]))
            let result = try check(makeClient()).get()
            XCTAssertFalse(result.isURLSafe)
            XCTAssertEqual(result.verificationStatus, .unrecognizedThreats)
            XCTAssertNil(result.safetyLevel)
        }
    }

    func testPackedUnpackedAndUnknownAttributesPreserveMeaning() throws {
        for attributes in [scalar(2, 1), message(2, varint(1) + varint(2))] {
            try respond(body(details: [scalar(1, 1) + attributes]))
            XCTAssertTrue(try check(makeClient()).get().isURLSafe, "CANARY/FRAME_ONLYは適用しない")
        }
        for attributes in [scalar(2, 99), message(2, varint(0)), message(2, varint(1) + varint(99))] {
            try respond(body(details: [scalar(1, 1) + attributes]))
            let result = try check(makeClient()).get()
            XCTAssertEqual(result.verificationStatus, .unrecognizedThreats)
            XCTAssertNil(result.safetyLevel)
            XCTAssertFalse(result.isURLSafe)
        }
    }

    func testKnownDangerIsRetainedWithUnknownProtobufDetail() throws {
        try respond(body(details: [scalar(1, 1), scalar(1, 99)]))
        let result = try check(makeClient()).get()
        XCTAssertEqual(result.verificationStatus, .unrecognizedThreats)
        XCTAssertEqual(result.safetyLevel, .danger)
    }

    func testMalformedResponseOrUnrequestedHashIsNotCached() throws {
        for invalid in try [Data([0x12, 0x02, 0x08]), body(details: [scalar(1, 1)], hash: Data(repeating: 0, count: 32))] {
            let service = makeClient()
            respond(invalid)
            guard case .failure(.parsingError) = try check(service) else { return XCTFail("不正応答を安全へ変換しない") }
            try respond(body(details: [scalar(1, 1)]))
            let result = try check(service).get()
            XCTAssertFalse(result.cacheHit)
            XCTAssertEqual(result.safetyLevel, .danger)
        }
    }

    func testUnknownContentTypeCannotProduceConfirmedSafe() throws {
        respond(Data("{\"cacheDuration\":\"60s\"}".utf8), mimeType: "text/html")
        guard case .failure(.parsingError) = try check(makeClient()) else { return XCTFail("不明な形式を安全として扱わない") }
    }

    private func makeClient() -> SafeBrowsingAPIClient {
        session?.invalidateAndCancel()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ProtobufURLProtocol.self]
        let session = URLSession(configuration: configuration)
        self.session = session
        return SafeBrowsingAPIClient(
            configuration: .init(apiKey: { "test-key" }, externalEnabled: { true }, suffixList: list), session: session
        )
    }

    private func respond(_ data: Data, mimeType: String = "application/x-protobuf") {
        ProtobufURLProtocol.handler = { _ in
            self.calls += 1
            return (data, mimeType)
        }
    }

    private func check(_ service: SafeBrowsingAPIClient) throws -> SafeBrowsingAPIClient.CheckResult {
        let done = expectation(description: "バイナリ照会の完了")
        var result: SafeBrowsingAPIClient.CheckResult?
        service.checkURL(url) { result = $0
            done.fulfill()
        }
        wait(for: [done], timeout: 3)
        return try XCTUnwrap(result)
    }

    private func body(details: [Data], hash: Data? = nil) throws -> Data {
        let value = try hash ?? XCTUnwrap(SafeBrowsingURLHasher(suffixList: list).fullHashes(for: url).first)
        let detailBytes = details.reduce(Data()) { $0 + message(2, $1) }
        return message(1, message(1, value) + detailBytes) + message(2, scalar(1, 60))
    }

    private func message(_ field: UInt8, _ data: Data) -> Data {
        Data([field << 3 | 2]) + varint(UInt64(data.count)) + data
    }

    private func scalar(_ field: UInt8, _ value: UInt64) -> Data {
        Data([field << 3]) + varint(value)
    }

    private func varint(_ input: UInt64) -> Data {
        var value = input
        var data = Data()
        while value >= 128 {
            data.append(UInt8(value & 0x7F) | 0x80)
            value >>= 7
        }
        data.append(UInt8(value))
        return data
    }
}

private final class ProtobufURLProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (Data, String))?
    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let (data, mimeType) = try XCTUnwrap(Self.handler)(request)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: XCTUnwrap(request.url), statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": mimeType]
            ))
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }

    override func stopLoading() {}
}
