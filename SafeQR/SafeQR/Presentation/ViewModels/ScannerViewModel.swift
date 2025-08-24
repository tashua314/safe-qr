import Foundation
import Combine

/**
 * ScannerViewControllerのビジネスロジック専用ViewModel
 * - QRコード処理とURL評価の調整
 * - 履歴管理
 * - 状態管理（MVVM）
 */
class ScannerViewModel: ObservableObject {
    
    // MARK: - Published Properties (UI Binding)
    
    /// スキャン状態
    @Published var scanStatus: ScanStatus = .ready
    
    /// 検出されたQRコード
    @Published var detectedQRCode: String?
    
    /// URL評価結果
    @Published var evaluationResult: URLEvaluationResult?
    
    /// エラー情報
    @Published var errorMessage: String?
    
    /// ライト（フラッシュ）の状態
    @Published var isLightEnabled: Bool = false
    
    // MARK: - Dependencies (Protocol-based for DI)
    
    private let qrProcessor: QRCodeProcessorProtocol
    private let urlEvaluator: URLEvaluationServiceProtocol
    private let historyRepository: HistoryRepositoryProtocol
    private let titleFetcher: HtmlTitleFetcherProtocol
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var processedURLs: Set<String> = []
    
    // MARK: - Initialization
    
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
        
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    /**
     * QRコード検出処理のエントリーポイント
     * @param qrCode: 検出されたQRコード文字列
     */
    func processDetectedQRCode(_ qrCode: String) {
        // 重複検出防止
        guard !processedURLs.contains(qrCode) else { 
            print("🔄 重複QRコード検出をスキップ: \(qrCode)")
            return 
        }
        
        // 状態更新
        scanStatus = .processing
        detectedQRCode = qrCode
        
        // QRコード処理を開始
        processQRCode(qrCode)
    }
    
    /**
     * ライトの切り替え
     */
    func toggleLight() {
        isLightEnabled.toggle()
        qrProcessor.setLightEnabled(isLightEnabled)
    }
    
    /**
     * スキャンのリセット（新しいスキャンを開始）
     */
    func resetScan() {
        scanStatus = .ready
        detectedQRCode = nil
        evaluationResult = nil
        errorMessage = nil
        processedURLs.removeAll()
    }
    
    /**
     * URLを安全に開く処理
     */
    func proceedWithURL(_ url: String, safetyLevel: SafetyLevel) {
        // 履歴に保存
        saveToHistory(url: url, safetyLevel: safetyLevel)
        
        // タイトル取得（後追い）
        fetchTitleAsync(for: url)
        
        // URLを開く通知
        NotificationCenter.default.post(
            name: .openURLRequested,
            object: url
        )
        
        // スキャンをリセット
        resetScan()
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // QRProcessor からの結果を監視
        qrProcessor.processingResult
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                self?.handleQRProcessingResult(result)
            }
            .store(in: &cancellables)
    }
    
    /**
     * QRコード処理の実行
     */
    private func processQRCode(_ qrCode: String) {
        processedURLs.insert(qrCode)
        
        // QRコードの基本検証
        let validationResult = qrProcessor.validateQRCode(qrCode)
        
        switch validationResult {
        case .valid(let url):
            evaluateURL(url)
        case .invalid(let error):
            handleProcessingError(error)
        case .duplicate:
            // 重複URLの処理：無視してスキャンを続行
            print("🔄 重複URL検出、無視してスキャンを続行: \(qrCode)")
            scanStatus = .ready
        }
    }
    
    /**
     * URL安全性評価の実行
     */
    private func evaluateURL(_ url: String) {
        // 即座評価（UX重視）
        let immediateSafety = urlEvaluator.evaluateImmediate(url: url) { [weak self] finalResult in
            DispatchQueue.main.async {
                self?.handleFinalEvaluationResult(url: url, result: finalResult)
            }
        }
        
        // 即座結果で初期評価結果を設定
        let initialResult = URLEvaluationResult(
            url: url,
            safetyLevel: immediateSafety,
            evaluationMethod: .local,
            responseTime: 0,
            detectedIssues: []
        )
        
        evaluationResult = initialResult
        scanStatus = .evaluated
        
        print("📋 評価完了: \(url) → \(immediateSafety.displayName)")
        
        // 安全でない場合は確認画面を表示（即座評価の詳細情報も取得）
        if immediateSafety != .safe {
            let localEvaluator = UrlRiskEvaluator()
            let detailedResult = localEvaluator.evaluateWithDetails(url: url)
            let issues = detailedResult.detectedIssues.map { issue in
                var issueText = "\(issue.category.emoji) \(issue.category.displayName): \(issue.description)"
                if let details = issue.details {
                    issueText += "\n・\(details)"
                }
                return issueText
            }
            showWarningDialog(for: url, safetyLevel: immediateSafety, issues: issues)
        }
    }
    
    /**
     * QR処理結果のハンドリング
     */
    private func handleQRProcessingResult(_ result: QRProcessingResult) {
        switch result {
        case .success(let url):
            evaluateURL(url)
        case .failure(let error):
            handleProcessingError(error)
        }
    }
    
    /**
     * 最終評価結果のハンドリング（API結果含む）
     */
    private func handleFinalEvaluationResult(url: String, result: EnhancedUrlRiskEvaluator.EvaluationResult) {
        let finalResult = URLEvaluationResult(
            url: url,
            safetyLevel: result.finalSafetyLevel,
            evaluationMethod: mapEvaluationMethod(result.evaluationMethod),
            responseTime: result.responseTime,
            detectedIssues: extractDetectedIssues(result)
        )
        
        evaluationResult = finalResult
        
        // 最終結果で確認画面を更新（詳細情報付き）
        if finalResult.safetyLevel != .safe {
            showWarningDialog(for: url, safetyLevel: finalResult.safetyLevel, issues: finalResult.detectedIssues)
        }
    }
    
    /**
     * 処理エラーのハンドリング
     */
    private func handleProcessingError(_ error: QRProcessingError) {
        errorMessage = error.localizedDescription
        scanStatus = .error
        
        print("❌ QR処理エラー: \(error.localizedDescription)")
    }
    
    /**
     * 履歴への保存
     */
    private func saveToHistory(url: String, safetyLevel: SafetyLevel) {
        do {
            try historyRepository.saveRecord(
                url: url, 
                safetyLevel: safetyLevel, 
                title: nil // 後追いで更新
            )
            // 履歴保存完了
        } catch {
            print("⚠️ 履歴保存エラー: \(error.localizedDescription)")
        }
    }
    
    /**
     * タイトル取得（非同期）
     */
    private func fetchTitleAsync(for url: String) {
        titleFetcher.fetchTitle(from: url) { [weak self] result in
            switch result {
            case .success(let title):
                self?.updateHistoryTitle(url: url, title: title)
            case .failure:
                // タイトル取得失敗（ログ非表示）
                break
            }
        }
    }
    
    /**
     * 履歴のタイトル更新
     */
    private func updateHistoryTitle(url: String, title: String) {
        do {
            try historyRepository.updateTitle(url: url, title: title)
            // タイトル更新完了
        } catch {
            print("⚠️ タイトル更新エラー: \(error.localizedDescription)")
        }
    }
    
    /**
     * 警告ダイアログの表示
     */
    private func showWarningDialog(for url: String, safetyLevel: SafetyLevel, issues: [String]) {
        let dialogInfo: [String: Any] = [
            "url": url,
            "safetyLevel": safetyLevel.rawValue,
            "detectedIssues": issues
        ]
        
        NotificationCenter.default.post(
            name: .showWarningDialog,
            object: dialogInfo
        )
    }
    
    // MARK: - Helper Methods
    
    private func mapEvaluationMethod(_ method: EnhancedUrlRiskEvaluator.EvaluationResult.EvaluationMethod) -> EvaluationMethod {
        switch method {
        case .localOnly:
            return .local
        case .hybridImmediate:
            return .hybrid
        case .hybridCached:
            return .cached
        case .localFallback:
            return .fallback
        }
    }
    
    private func extractDetectedIssues(_ result: EnhancedUrlRiskEvaluator.EvaluationResult) -> [String] {
        var issues: [String] = []
        
        // ローカル評価の結果を含める
        if result.localResult != .safe {
            // ローカル評価の詳細を取得
            let localEvaluator = UrlRiskEvaluator()
            if let urlString = evaluationResult?.url,
               let url = URL(string: urlString) {
                let detailedResult = localEvaluator.evaluateWithDetails(url: url.absoluteString)
                for issue in detailedResult.detectedIssues {
                    var issueText = "\(issue.category.emoji) \(issue.category.displayName): \(issue.description)"
                    if let details = issue.details {
                        issueText += "\n・\(details)"
                    }
                    issues.append(issueText)
                }
            }
        }
        
        // API結果から脅威情報を抽出
        if let apiResult = result.apiResult {
            for threat in apiResult.detectedThreats {
                issues.append("API検出: \(threat.rawValue)")
            }
        } else if result.evaluationMethod == .localFallback {
            // APIエラーの場合
            issues.append("外部API確認失敗（ローカル評価のみ）")
        }
        
        return issues
    }
}

// MARK: - Supporting Types

/// スキャン状態
enum ScanStatus {
    case ready          // スキャン待機中
    case processing     // 処理中
    case evaluated      // 評価完了
    case error          // エラー発生
}

/// URL評価結果（UIバインディング用）
struct URLEvaluationResult {
    let url: String
    let safetyLevel: SafetyLevel
    let evaluationMethod: EvaluationMethod
    let responseTime: Double
    let detectedIssues: [String]
}

/// 評価方法
enum EvaluationMethod {
    case local      // ローカル評価のみ
    case hybrid     // ハイブリッド（ローカル＋API）
    case cached     // キャッシュヒット
    case fallback   // フォールバック
}

/// QR処理結果
enum QRProcessingResult {
    case success(String)  // 有効なURL
    case failure(QRProcessingError)  // 処理エラー
}

/// QR処理エラー
enum QRProcessingError: LocalizedError {
    case invalidFormat
    case unsupportedScheme
    case malformed
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "QRコードの形式が無効です"
        case .unsupportedScheme:
            return "サポートされていないURLです"
        case .malformed:
            return "URLの形式が正しくありません"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openURLRequested = Notification.Name("openURLRequested")
    static let showWarningDialog = Notification.Name("showWarningDialog")
}