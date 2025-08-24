import Foundation
import Combine
import UIKit
import QuartzCore

/**
 * アプリケーション全体で使用するプロトコル定義
 * - 依存性注入（DI）のための抽象化
 * - テスタビリティの向上
 * - 疎結合の実現
 */

// MARK: - QR Scanner Service Protocol

protocol QRScannerServiceProtocol {
    /// スキャン結果の通知
    var scanResult: AnyPublisher<String, Never> { get }
    
    /// スキャンの開始
    func startScanning()
    
    /// スキャンの停止  
    func stopScanning()
    
    /// トーチ（フラッシュライト）の設定
    func setTorchEnabled(_ enabled: Bool)
    
    /// カメラプレビューレイヤーの取得
    func getPreviewLayer() -> CALayer?
    
    /// カメラアクセス許可の要求
    func requestCameraPermission(completion: @escaping (Bool) -> Void)
    
    /// キャプチャセッションのセットアップ
    func setupCaptureSession(in view: UIView)
    
    /// プレビューレイヤーのフレーム更新
    func updatePreviewLayer(frame: CGRect)
}

// MARK: - URL Evaluation Service Protocol

protocol URLEvaluationServiceProtocol {
    /// 即座評価（ローカル結果を即座に返し、API結果は非同期）
    func evaluateImmediate(url: String, completion: ((EnhancedUrlRiskEvaluator.EvaluationResult) -> Void)?) -> SafetyLevel
    
    /// 完全評価（ローカル+API評価完了まで待機）
    func evaluateComplete(url: String, completion: @escaping (EnhancedUrlRiskEvaluator.EvaluationResult) -> Void)
    
    /// 複数URL一括評価
    func evaluateMultiple(urls: [String], completion: @escaping ([String: EnhancedUrlRiskEvaluator.EvaluationResult]) -> Void)
}

// MARK: - History Repository Protocol

protocol HistoryRepositoryProtocol {
    /// 履歴記録の保存
    func saveRecord(url: String, safetyLevel: SafetyLevel, title: String?) throws
    
    /// 全履歴の取得
    func getAllRecords() throws -> [ScanRecord]
    
    /// 履歴の削除
    func deleteRecord(with id: UUID) throws
    
    /// 全履歴の削除
    func deleteAllRecords() throws
    
    /// タイトルの更新
    func updateTitle(url: String, title: String) throws
    
    /// 履歴件数の取得
    func getRecordCount() throws -> Int
}

// MARK: - HTML Title Fetcher Protocol

protocol HtmlTitleFetcherProtocol {
    /// HTMLタイトルの取得
    func fetchTitle(from url: String, completion: @escaping (Result<String, HtmlTitleFetcher.TitleFetchError>) -> Void)
    
    /// タイトル取得のキャンセル
    func cancelFetch(for url: String)
}


// MARK: - Settings Store Protocol

protocol SettingsStoreProtocol {
    /// 安全性の厳しさ設定
    var safetyStrictness: SafetyStrictness { get set }
    
    /// 外部レピュテーション使用設定
    var isExternalReputationEnabled: Bool { get set }
    
    /// 設定変更通知
    var settingsChanged: AnyPublisher<Void, Never> { get }
}

// MARK: - Safe Browsing API Client Protocol

protocol SafeBrowsingAPIClientProtocol {
    /// URL安全性チェック
    func checkURL(_ url: String, completion: @escaping (Result<SafeBrowsingAPIClient.SafeBrowsingResult, SafeBrowsingAPIClient.SafeBrowsingError>) -> Void)
    
    /// 複数URL一括チェック
    func checkURLs(_ urls: [String], completion: @escaping ([String: SafeBrowsingAPIClient.SafeBrowsingResult]) -> Void)
}

// MARK: - UI Manager Protocol

protocol ScannerUIManagerProtocol {
    /// UI要素のセットアップ
    func setupUI(in viewController: UIViewController)
    
    /// レイアウトの更新
    func updateLayout()
    
    /// 状態に応じたUI更新
    func updateUI(for status: ScanStatus)
    
    /// ボタンアクションの設定
    func setButtonActions(
        historyAction: @escaping () -> Void,
        settingsAction: @escaping () -> Void,
        lightAction: @escaping () -> Void
    )
}

// MARK: - Coordinator Protocol

protocol CoordinatorProtocol {
    /// 子Coordinatorの管理
    var childCoordinators: [CoordinatorProtocol] { get set }
    
    /// ナビゲーション開始
    func start()
}

protocol ScannerCoordinatorProtocol: CoordinatorProtocol {
    /// 確認ダイアログの表示
    func showConfirmationDialog(for url: String, safetyLevel: SafetyLevel, completion: @escaping (Bool) -> Void)
    
    /// 履歴画面への遷移
    func showHistory()
    
    /// 設定画面への遷移
    func showSettings()
    
    /// URLを開く
    func openURL(_ url: String)
}

// MARK: - Logger Protocol

protocol LoggerProtocol {
    func log(_ message: String, level: LogLevel, category: LogCategory)
    func error(_ message: String, error: Error?, category: LogCategory)
}

enum LogLevel {
    case debug, info, warning, error
}

enum LogCategory: String, CaseIterable {
    case qrProcessing = "QR_PROCESSING"
    case urlEvaluation = "URL_EVALUATION"
    case networking = "NETWORKING"
    case ui = "UI"
    case history = "HISTORY"
    case security = "SECURITY"
}

// MARK: - Dependency Injection Protocol

protocol DIContainerProtocol {
    func register<T>(_ type: T.Type, factory: @escaping () -> T)
    func resolve<T>(_ type: T.Type) -> T
}

// MARK: - Validation Protocols

protocol URLValidatorProtocol {
    func validate(_ url: String) -> URLValidationResult
}

enum URLValidationResult {
    case valid(String)
    case invalid(URLValidationError)
}

enum URLValidationError: LocalizedError {
    case malformedURL
    case unsupportedScheme
    case localNetworkNotAllowed
    case dangerousPort
    
    var errorDescription: String? {
        switch self {
        case .malformedURL:
            return "URLの形式が正しくありません"
        case .unsupportedScheme:
            return "サポートされていないプロトコルです"
        case .localNetworkNotAllowed:
            return "ローカルネットワークへのアクセスは許可されていません"
        case .dangerousPort:
            return "危険なポート番号が指定されています"
        }
    }
}

// MARK: - Cache Protocol

protocol CacheProtocol {
    associatedtype Key
    associatedtype Value
    
    func get(for key: Key) -> Value?
    func set(_ value: Value, for key: Key)
    func remove(for key: Key)
    func clear()
}

// MARK: - Repository Base Protocol

protocol RepositoryProtocol {
    associatedtype Entity
    associatedtype ID
    
    func save(_ entity: Entity) throws
    func findById(_ id: ID) throws -> Entity?
    func findAll() throws -> [Entity]
    func delete(by id: ID) throws
    func deleteAll() throws
}

// MARK: - Analytics Protocol

protocol AnalyticsProtocol {
    func track(event: AnalyticsEvent, parameters: [String: Any]?)
    func setUserProperty(_ property: String, value: Any)
}

enum AnalyticsEvent: String {
    case qrScanned = "qr_scanned"
    case urlOpened = "url_opened"
    case safetyWarningShown = "safety_warning_shown"
    case settingsChanged = "settings_changed"
    case historyViewed = "history_viewed"
}

// MARK: - Error Handling Protocols

protocol ErrorHandlerProtocol {
    func handle(_ error: Error, context: ErrorContext)
}

struct ErrorContext {
    let operation: String
    let userInfo: [String: Any]
    let shouldShowUser: Bool
}