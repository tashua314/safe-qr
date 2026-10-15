import Combine
import Foundation
@testable import SafeQR
import XCTest

final class ScanConsentTests: XCTestCase {
    private let url = "https://example.invalid/private?token=consent-test"
    private let evaluator = ConsentEvaluator()
    private let history = ConsentHistory()
    private let titles = ConsentTitleFetcher()

    private func model() -> ScannerViewModel {
        ScannerViewModel(qrProcessor: ConsentQRProcessor(), urlEvaluator: evaluator, historyRepository: history, titleFetcher: titles)
    }

    private func flushMain() {
        let done = expectation(description: "メインキューの処理完了")
        DispatchQueue.main.async { done.fulfill() }
        wait(for: [done], timeout: 2)
    }

    func testDelayedDangerDoesNotContactTargetBeforeDecision() throws {
        let model = model()
        model.processDetectedQRCode(url)
        XCTAssertEqual(model.scanStatus, .processing)
        XCTAssertNil(model.evaluationResult)
        XCTAssertNil(model.urlToOpen)
        XCTAssertTrue(history.saved.isEmpty)
        XCTAssertTrue(titles.requests.isEmpty)
        evaluator.respond(level: .danger)
        flushMain()
        let result = try XCTUnwrap(model.evaluationResult)
        XCTAssertTrue(result.requiresConfirmation)
        XCTAssertEqual(history.saved.map(\.level), [.danger])
        XCTAssertTrue(titles.requests.isEmpty)
        XCTAssertNil(model.urlToOpen)
        model.approve(result)
        XCTAssertEqual(titles.requests, [url])
        XCTAssertEqual(model.urlToOpen, url)
    }

    func testCautionCancelPreservesUntitledHistoryWithoutRequest() throws {
        let model = model()
        model.processDetectedQRCode(url)
        evaluator.respond(level: .caution)
        flushMain()
        let result = try XCTUnwrap(model.evaluationResult)
        model.cancel(result)
        XCTAssertEqual(history.saved.count, 1)
        XCTAssertNil(history.saved.first?.title)
        XCTAssertTrue(titles.requests.isEmpty)
        XCTAssertNil(model.urlToOpen)
        model.processDetectedQRCode(url)
        evaluator.respond(index: 1, level: .caution)
        flushMain()
        XCTAssertEqual(history.saved.count, 2)
        XCTAssertTrue(titles.requests.isEmpty)
    }

    func testUnverifiedExternalResultRequiresConfirmationEvenWhenLocalSafe() throws {
        let model = model()
        model.processDetectedQRCode(url)
        evaluator.respond(level: .safe, method: .localFallback)
        flushMain()
        let result = try XCTUnwrap(model.evaluationResult)
        XCTAssertTrue(result.requiresConfirmation)
        XCTAssertEqual(result.evaluationMethod, .fallback)
        XCTAssertFalse(result.detectedIssues.isEmpty)
        model.cancel(result)
        XCTAssertTrue(titles.requests.isEmpty)
        XCTAssertNil(model.urlToOpen)
    }

    func testCancelledEvaluationCannotPublishIntoNewScan() throws {
        let model = model()
        model.processDetectedQRCode(url)
        model.resetScan()
        model.processDetectedQRCode(url)
        evaluator.respond(index: 0, level: .safe)
        flushMain()
        XCTAssertNil(model.evaluationResult)
        XCTAssertTrue(history.saved.isEmpty)
        evaluator.respond(index: 1, level: .danger)
        flushMain()
        XCTAssertEqual(try XCTUnwrap(model.evaluationResult).safetyLevel, .danger)
        XCTAssertEqual(history.saved.count, 1)
        XCTAssertTrue(titles.requests.isEmpty)
    }

    func testOtherQRAndRepeatedCallbackCannotReplacePendingDecision() throws {
        let model = model()
        model.processDetectedQRCode(url)
        model.processDetectedQRCode("https://other.invalid")
        XCTAssertEqual(evaluator.requests, [url])
        evaluator.respond(level: .caution)
        flushMain()
        let first = try XCTUnwrap(model.evaluationResult)
        evaluator.respond(level: .safe)
        model.processDetectedQRCode("https://other.invalid")
        flushMain()
        XCTAssertEqual(model.evaluationResult?.id, first.id)
        XCTAssertEqual(model.evaluationResult?.safetyLevel, .caution)
        XCTAssertEqual(history.saved.count, 1)
        XCTAssertEqual(evaluator.requests.count, 1)
    }

    func testOpeningConsumesDecisionOnlyOnce() throws {
        let model = model()
        model.processDetectedQRCode(url)
        evaluator.respond(level: .danger)
        flushMain()
        let result = try XCTUnwrap(model.evaluationResult)
        model.approve(result)
        model.approve(result)
        model.cancel(result)
        XCTAssertEqual(titles.requests.count, 1)
        XCTAssertEqual(history.saved.count, 1)
        XCTAssertEqual(model.scanStatus, .opening)
        XCTAssertEqual(model.urlToOpen, url)
    }

    func testLateTitleCannotOverwriteNewerApprovedTitle() throws {
        let model = model()
        for index in 0 ... 1 {
            model.processDetectedQRCode(url)
            evaluator.respond(index: index, level: .caution)
            flushMain()
            try model.approve(XCTUnwrap(model.evaluationResult))
            model.resetScan()
        }
        titles.completions[1](.success("新しいタイトル"))
        titles.completions[0](.success("古いタイトル"))
        flushMain()
        XCTAssertEqual(history.updatedTitles, ["新しいタイトル"])
        XCTAssertEqual(history.saved.count, 2)
    }

    func testHistoryCancelDoesNotCountVisitAndApprovalUsesFinalRisk() throws {
        let model = model()
        model.processHistoryURL(url)
        evaluator.respond(level: .danger)
        flushMain()
        try model.cancel(XCTUnwrap(model.evaluationResult))
        XCTAssertTrue(history.saved.isEmpty)
        XCTAssertTrue(titles.requests.isEmpty)
        model.processHistoryURL(url)
        evaluator.respond(index: 1, level: .danger)
        flushMain()
        try model.approve(XCTUnwrap(model.evaluationResult))
        XCTAssertEqual(history.saved.map(\.level), [.danger])
        XCTAssertEqual(titles.requests, [url])
    }

    func testCompletedLocalSafeCanOpenWithoutWarningButNeverPrefetches() throws {
        let model = model()
        model.processDetectedQRCode(url)
        evaluator.respond(level: .safe, method: .localOnly)
        flushMain()
        let result = try XCTUnwrap(model.evaluationResult)
        XCTAssertFalse(result.requiresConfirmation)
        XCTAssertTrue(titles.requests.isEmpty)
        model.approve(result)
        XCTAssertEqual(titles.requests.count, 1)
    }

    func testInvalidInputNeverReachesEvaluationOrNetwork() {
        let model = model()
        model.processDetectedQRCode("not-a-url")
        XCTAssertEqual(model.scanStatus, .error)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertTrue(evaluator.requests.isEmpty)
        XCTAssertTrue(history.saved.isEmpty)
        XCTAssertTrue(titles.requests.isEmpty)
    }

    func testTitleRedirectDelegateRejectsDestination() throws {
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let source = try XCTUnwrap(URL(string: url))
        let destination = try XCTUnwrap(URL(string: "https://unapproved.invalid/"))
        let response = try XCTUnwrap(HTTPURLResponse(
            url: source,
            statusCode: 302,
            httpVersion: nil,
            headerFields: ["Location": destination.absoluteString]
        ))
        var called = false
        HtmlTitleSessionDelegate().urlSession(
            session, task: session.dataTask(with: source), willPerformHTTPRedirection: response,
            newRequest: URLRequest(url: destination)
        ) { request in
            called = true
            XCTAssertNil(request)
        }
        XCTAssertTrue(called)
    }
}

private final class ConsentQRProcessor: QRCodeProcessorProtocol {
    var processingResult: AnyPublisher<QRProcessingResult, Never> {
        Empty().eraseToAnyPublisher()
    }

    func validateQRCode(_ value: String) -> QRValidationResult {
        guard let url = URL(string: value), url.host != nil, ["http", "https"].contains(url.scheme) else { return .invalid(.malformed) }
        return .valid(value)
    }

    func setLightEnabled(_: Bool) {}
    func resetProcessedURLs() {}
}

private final class ConsentEvaluator: URLEvaluationServiceProtocol {
    var requests: [String] = []
    var completions: [(EnhancedUrlRiskEvaluator.EvaluationResult) -> Void] = []
    func evaluateComplete(url: String, completion: @escaping (EnhancedUrlRiskEvaluator.EvaluationResult) -> Void) {
        requests.append(url)
        completions.append(completion)
    }

    func respond(
        index: Int = 0,
        level: SafetyLevel,
        method: EnhancedUrlRiskEvaluator.EvaluationResult.EvaluationMethod = .hybridImmediate
    ) {
        completions[index](.init(finalSafetyLevel: level, localResult: .safe, apiResult: nil, evaluationMethod: method, responseTime: 1))
    }

    func evaluateImmediate(url _: String, completion _: ((EnhancedUrlRiskEvaluator.EvaluationResult) -> Void)?) -> SafetyLevel {
        XCTFail("開封前に完全評価を待つ必要がある")
        return .safe
    }

    func evaluateMultiple(urls _: [String], completion _: @escaping ([String: EnhancedUrlRiskEvaluator.EvaluationResult]) -> Void) {}
}

private final class ConsentTitleFetcher: HtmlTitleFetcherProtocol {
    var requests: [String] = []
    var completions: [(Result<String, Error>) -> Void] = []
    func fetchTitle(from url: String, completion: @escaping (Result<String, Error>) -> Void) {
        requests.append(url)
        completions.append(completion)
    }
}

private final class ConsentHistory: HistoryRepositoryProtocol {
    struct Saved { let url: String
        let level: SafetyLevel
        let title: String?
    }

    var saved: [Saved] = []
    var updatedTitles: [String] = []
    func saveRecord(url: String, safetyLevel: SafetyLevel, title: String?) throws {
        saved.append(Saved(
            url: url,
            level: safetyLevel,
            title: title
        ))
    }

    func updateTitle(url _: String, title: String) throws {
        updatedTitles.append(title)
    }

    func getAllRecords() throws -> [ScanRecord] {
        []
    }

    func deleteRecord(with _: UUID) throws {}
    func deleteAllRecords() throws {}
    func getRecordCount() throws -> Int {
        saved.count
    }
}
