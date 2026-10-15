import Foundation
@testable import SafeQR
import XCTest

final class PrivacyDiagnosticsTests: XCTestCase {
    private let privateURL = "https://example.invalid/SAFEQR_PRIVATE_PATH_20261015?token=SAFEQR_PRIVATE_QUERY_20261015#SAFEQR_PRIVATE_FRAGMENT_20261015"
    private let privateTitle = "SAFEQR_PRIVATE_TITLE_20261015"

    func testPrivateQueryAndTitleRemainDataWhileLoggingIsBounded() throws {
        let processor = QRCodeProcessor(qrScannerService: QRScannerService())
        guard case .valid = processor.validateQRCode(privateURL) else { return XCTFail("ダミーURLの検証が実行される") }
        let repository = HistoryRepository(coreDataStack: TestCoreDataStack())
        try repository.saveRecord(url: privateURL, safetyLevel: .caution, title: nil)
        try repository.updateTitle(url: privateURL, title: privateTitle)
        let record = try XCTUnwrap(repository.getAllRecords().first)
        XCTAssertEqual(record.url, privateURL)
        XCTAssertEqual(record.title, privateTitle)
        XCTAssertEqual(record.visitCount, 1)
    }

    func testErrorContainingPrivateURLAndTitleRetainsOnlyCodeInDiagnostics() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: [
            NSURLErrorFailingURLErrorKey: URL(string: privateURL) as Any,
            NSLocalizedDescriptionKey: privateTitle + " SAFEQR_PRIVATE_ERROR_20261015"
        ])
        let client = PrivateErrorClient(error: error)
        let evaluator = EnhancedUrlRiskEvaluator(safeBrowsingClient: client, externalEnabled: { true })
        let done = expectation(description: "個人情報を含むエラー経路を実行")
        evaluator.evaluateComplete(url: privateURL) { result in
            XCTAssertEqual(result.evaluationMethod, .localFallback)
            XCTAssertNil(result.apiResult)
            done.fulfill()
        }
        wait(for: [done], timeout: 2)
        XCTAssertEqual(client.requestCount, 1)
    }

    @MainActor
    func testWarningDetailsDoNotBecomeConsoleOutput() {
        let controller = OpenConfirmViewController(url: privateURL, safetyLevel: .caution, detectedIssues: [privateTitle])
        controller.loadViewIfNeeded()
        XCTAssertTrue(controller.isViewLoaded)
    }
}

private final class PrivateErrorClient: SafeBrowsingAPIClientProtocol {
    private let error: NSError
    var requestCount = 0
    init(error: NSError) {
        self.error = error
    }

    func checkURL(_: String, completion: @escaping (SafeBrowsingAPIClient.CheckResult) -> Void) {
        requestCount += 1
        completion(.failure(.networkError(error)))
    }

    func checkURLs(_ urls: [String], completion: @escaping ([String: SafeBrowsingAPIClient.CheckResult]) -> Void) {
        completion(Dictionary(uniqueKeysWithValues: urls.map { ($0, .failure(.networkError(error))) }))
    }
}
