import Combine
import Foundation

/// 評価を完了し、必要な開封確認を通した後だけスキャン先への通信を許可する。
class ScannerViewModel: ObservableObject {
    @Published private(set) var scanStatus: ScanStatus = .ready
    @Published private(set) var detectedQRCode: String?
    @Published private(set) var evaluationResult: URLEvaluationResult?
    @Published private(set) var urlToOpen: String?
    @Published private(set) var errorMessage: String?
    @Published var isLightEnabled = false

    private let qrProcessor: QRCodeProcessorProtocol
    private let urlEvaluator: URLEvaluationServiceProtocol
    private let historyRepository: HistoryRepositoryProtocol
    private let titleFetcher: HtmlTitleFetcherProtocol
    private var activeEvaluationID: UUID?
    private var recordOnEvaluation = true
    private var titleRequests: [String: UUID] = [:]

    init(
        qrProcessor: QRCodeProcessorProtocol,
        urlEvaluator: URLEvaluationServiceProtocol,
        historyRepository: HistoryRepositoryProtocol,
        titleFetcher: HtmlTitleFetcherProtocol
    ) {
        self.qrProcessor = qrProcessor
        self.urlEvaluator = urlEvaluator
        self.historyRepository = historyRepository
        self.titleFetcher = titleFetcher
    }

    func processDetectedQRCode(_ qrCode: String) {
        beginEvaluation(qrCode, recordOnEvaluation: true)
    }

    func processHistoryURL(_ url: String) {
        beginEvaluation(url, recordOnEvaluation: false)
    }

    func toggleLight() {
        isLightEnabled.toggle()
        qrProcessor.setLightEnabled(isLightEnabled)
    }

    func resetScan() {
        activeEvaluationID = nil
        evaluationResult = nil
        urlToOpen = nil
        errorMessage = nil
        detectedQRCode = nil
        scanStatus = .ready
        qrProcessor.resetProcessedURLs()
    }

    func isCurrent(_ result: URLEvaluationResult) -> Bool {
        activeEvaluationID == result.id && evaluationResult?.id == result.id
    }

    func cancel(_ result: URLEvaluationResult) {
        guard isCurrent(result) else { return }
        resetScan()
    }

    func approve(_ result: URLEvaluationResult) {
        guard isCurrent(result) else { return }
        // 決定を先に消費する。遅延コールバックや連打で通信と訪問回数を重複させない。
        activeEvaluationID = nil
        evaluationResult = nil
        scanStatus = .opening
        if !recordOnEvaluation { saveToHistory(url: result.url, safetyLevel: result.safetyLevel) }
        fetchApprovedTitle(for: result.url)
        urlToOpen = result.url
    }

    private func beginEvaluation(_ value: String, recordOnEvaluation: Bool) {
        guard scanStatus == .ready else { return }
        self.recordOnEvaluation = recordOnEvaluation
        detectedQRCode = value
        scanStatus = .processing
        switch qrProcessor.validateQRCode(value) {
        case let .valid(url):
            let identifier = UUID()
            activeEvaluationID = identifier
            urlEvaluator.evaluateComplete(url: url) { [weak self] result in
                DispatchQueue.main.async {
                    self?.finishEvaluation(url: url, id: identifier, result: result)
                }
            }
        case let .invalid(error):
            errorMessage = error.localizedDescription
            scanStatus = .error
        case .duplicate:
            resetScan()
        }
    }

    private func finishEvaluation(url: String, id: UUID, result: EnhancedUrlRiskEvaluator.EvaluationResult) {
        guard activeEvaluationID == id, scanStatus == .processing else { return }
        let finalResult = URLEvaluationResult(
            id: id,
            url: url,
            safetyLevel: result.finalSafetyLevel,
            evaluationMethod: mapEvaluationMethod(result.evaluationMethod),
            responseTime: result.responseTime,
            detectedIssues: extractDetectedIssues(result, url: url)
        )
        if recordOnEvaluation { saveToHistory(url: url, safetyLevel: result.finalSafetyLevel) }
        scanStatus = .evaluated
        evaluationResult = finalResult
    }

    private func saveToHistory(url: String, safetyLevel: SafetyLevel) {
        do {
            try historyRepository.saveRecord(url: url, safetyLevel: safetyLevel, title: nil)
        } catch {
            AppLog.error(.historySaveFailed, code: (error as NSError).code)
        }
    }

    private func fetchApprovedTitle(for url: String) {
        let identifier = UUID()
        titleRequests[url] = identifier
        titleFetcher.fetchTitle(from: url) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self, self.titleRequests[url] == identifier else { return }
                self.titleRequests.removeValue(forKey: url)
                if case let .success(title) = result {
                    do {
                        try self.historyRepository.updateTitle(url: url, title: title)
                    } catch {
                        AppLog.error(.titleUpdateFailed, code: (error as NSError).code)
                    }
                }
            }
        }
    }

    private func mapEvaluationMethod(_ method: EnhancedUrlRiskEvaluator.EvaluationResult.EvaluationMethod) -> EvaluationMethod {
        switch method {
        case .localOnly: return .local
        case .hybridImmediate: return .hybrid
        case .hybridCached: return .cached
        case .localFallback: return .fallback
        }
    }

    private func extractDetectedIssues(_ result: EnhancedUrlRiskEvaluator.EvaluationResult, url: String) -> [String] {
        var issues = UrlRiskEvaluator().evaluateWithDetails(url: url).detectedIssues.map { issue in
            var text = "\(issue.category.emoji) \(issue.category.displayName): \(issue.description)"
            if let details = issue.details { text += "\n・\(details)" }
            return text
        }
        if let apiResult = result.apiResult {
            if apiResult.verificationStatus == .unrecognizedThreats {
                issues.append("外部チェックに未対応の脅威情報が含まれています（安全性は未確認）")
            }
            issues += apiResult.detectedThreats.map { "API検出: \($0.rawValue)" }
        } else if result.evaluationMethod == .localFallback {
            issues.append("外部チェックを完了できませんでした（ローカル評価のみ）")
        }
        return issues
    }
}

enum ScanStatus {
    case ready, processing, evaluated, opening, error
}

struct URLEvaluationResult {
    let id: UUID
    let url: String
    let safetyLevel: SafetyLevel
    let evaluationMethod: EvaluationMethod
    let responseTime: Double
    let detectedIssues: [String]

    var requiresConfirmation: Bool {
        safetyLevel != .safe || evaluationMethod == .fallback
    }
}

enum EvaluationMethod {
    case local, hybrid, cached, fallback
}

enum QRProcessingResult {
    case success(String)
    case failure(QRProcessingError)
}

enum QRProcessingError: LocalizedError {
    case invalidFormat, unsupportedScheme, malformed

    var errorDescription: String? {
        switch self {
        case .invalidFormat: return "QRコードの形式が無効です"
        case .unsupportedScheme: return "サポートされていないURLです"
        case .malformed: return "URLの形式が正しくありません"
        }
    }
}
