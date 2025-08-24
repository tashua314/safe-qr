import Foundation
import Combine
import QuartzCore
import UIKit

/**
 * 簡易依存性注入コンテナ
 * - サービスの登録と解決
 * - シングルトンとファクトリパターンの対応
 * - プロトコルベースの抽象化
 */
class DIContainer: DIContainerProtocol {
    
    // MARK: - Shared Instance
    
    static let shared = DIContainer()
    
    private init() {
        registerDefaultServices()
    }
    
    // MARK: - Private Properties
    
    private var services: [String: Any] = [:]
    private var factories: [String: () -> Any] = [:]
    
    // MARK: - Public Methods
    
    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        factories[key] = factory
    }
    
    func registerSingleton<T>(_ type: T.Type, instance: T) {
        let key = String(describing: type)
        services[key] = instance
    }
    
    func resolve<T>(_ type: T.Type) -> T {
        let key = String(describing: type)
        
        // シングルトンインスタンスがある場合
        if let instance = services[key] as? T {
            return instance
        }
        
        // ファクトリがある場合
        if let factory = factories[key] {
            let instance = factory() as! T
            return instance
        }
        
        // 登録されていない場合はクラッシュ（開発時にミスを発見しやすくする）
        fatalError("Service of type \(type) is not registered")
    }
    
    func resolveSingleton<T>(_ type: T.Type) -> T {
        let key = String(describing: type)
        
        // 既にシングルトンが存在する場合
        if let instance = services[key] as? T {
            return instance
        }
        
        // ファクトリからシングルトンを作成
        if let factory = factories[key] {
            let instance = factory() as! T
            services[key] = instance
            return instance
        }
        
        fatalError("Service of type \(type) is not registered")
    }
    
    // MARK: - Default Services Registration
    
    private func registerDefaultServices() {
        // Core Services (Concrete implementations)
        register(QRScannerServiceProtocol.self) { 
            QRScannerService() 
        }
        
        register(URLEvaluationServiceProtocol.self) { 
            EnhancedUrlRiskEvaluator() 
        }
        
        register(HistoryRepositoryProtocol.self) { 
            HistoryRepository() 
        }
        
        register(HtmlTitleFetcherProtocol.self) { 
            HtmlTitleFetcher() 
        }
        
        register(SafeBrowsingAPIClientProtocol.self) { 
            SafeBrowsingAPIClient() 
        }
        
        register(SettingsStoreProtocol.self) { 
            SettingsStore.shared 
        }
        
        // Processing Services
        register(QRCodeProcessorProtocol.self) { [unowned self] in
            let qrService = self.resolve(QRScannerServiceProtocol.self)
            return QRCodeProcessor(qrScannerService: qrService) as QRCodeProcessorProtocol
        }
        
        // UI Services
        register(ScannerUIManagerProtocol.self) { 
            ScannerUIManager() 
        }
        
        // ViewModels
        register(ScannerViewModel.self) { [unowned self] in
            ScannerViewModel(
                qrProcessor: self.resolve(QRCodeProcessorProtocol.self),
                urlEvaluator: self.resolve(URLEvaluationServiceProtocol.self),
                historyRepository: self.resolve(HistoryRepositoryProtocol.self),
                titleFetcher: self.resolve(HtmlTitleFetcherProtocol.self)
            )
        }
        
        #if DEBUG
        // registerMockServices() // コメントアウト - 必要時のみ有効化
        #endif
    }
    
    // MARK: - Mock Services (Debug only)
    
    #if DEBUG
    func useMockServices() {
        // テスト時にモックサービスに切り替え
        register(QRCodeProcessorProtocol.self) { 
            MockQRCodeProcessor() 
        }
    }
    #endif
    
    // MARK: - Utility Methods
    
    func isRegistered<T>(_ type: T.Type) -> Bool {
        let key = String(describing: type)
        return services.keys.contains(key) || factories.keys.contains(key)
    }
    
    func clear() {
        services.removeAll()
        factories.removeAll()
        registerDefaultServices()
    }
}

// MARK: - Extensions for Easy Protocol Conformance

extension QRScannerService: QRScannerServiceProtocol {
    var scanResult: AnyPublisher<String, Never> {
        return NotificationCenter.default
            .publisher(for: .qrCodeDetected)
            .compactMap { $0.object as? String }
            .eraseToAnyPublisher()
    }
    
    func setTorchEnabled(_ enabled: Bool) {
        // 既存のライト機能があれば使用、なければ仮実装
        print("🔦 ライト設定: \(enabled ? "ON" : "OFF")")
    }
    
    func getPreviewLayer() -> CALayer? {
        // videoPreviewLayerが存在すれば返す（privateなので仮実装）
        return nil
    }
    
    func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        // 仮実装：実際のプロジェクトでは適切な実装に置き換え
        DispatchQueue.main.async {
            completion(true)
        }
    }
    
    func setupCaptureSession(in view: UIView) {
        // 既存のsetupCameraメソッドを使用
        setupCamera(in: view)
    }
}

extension EnhancedUrlRiskEvaluator: URLEvaluationServiceProtocol {
    // 既存のメソッドがプロトコルに適合しているので追加実装不要
}

extension HistoryRepository: HistoryRepositoryProtocol {
    func saveRecord(url: String, safetyLevel: SafetyLevel, title: String?) throws {
        // ScanRecordを作成してupsert（domainHashは簡易計算）
        let domainHash = url.components(separatedBy: "/")[2].hash
        let record = ScanRecord(url: url, safety: safetyLevel, domainHash: String(domainHash))
        upsertScanRecord(record)
    }
    
    func getAllRecords() throws -> [ScanRecord] {
        return fetchAllScanRecords()
    }
    
    func deleteRecord(with id: UUID) throws {
        deleteScanRecord(by: id)
    }
    
    func deleteAllRecords() throws {
        deleteAllScanRecords()
    }
    
    func updateTitle(url: String, title: String) throws {
        // 既存の実装があればそれを使用、なければ仮実装
        print("📝 タイトル更新: \(url) -> \(title)")
    }
    
    func getRecordCount() throws -> Int {
        return fetchAllScanRecords().count
    }
}

extension HtmlTitleFetcher: HtmlTitleFetcherProtocol {
    func fetchTitle(from url: String, completion: @escaping (Result<String, HtmlTitleFetcher.TitleFetchError>) -> Void) {
        // 既存のfetchTitleメソッドを呼び出し、結果を変換
        fetchTitle(from: url) { result in
            switch result {
            case .success(let titleResult):
                completion(.success(titleResult.title ?? "無題"))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func cancelFetch(for url: String) {
        // 既存の実装があればそれを使用、なければ仮実装
        print("🚫 タイトル取得キャンセル: \(url)")
    }
}

extension SafeBrowsingAPIClient: SafeBrowsingAPIClientProtocol {
    // 既存のメソッドがプロトコルに適合しているので追加実装不要
}

extension SettingsStore: SettingsStoreProtocol {
    var settingsChanged: AnyPublisher<Void, Never> {
        return NotificationCenter.default
            .publisher(for: .settingsChanged)
            .map { _ in () }
            .eraseToAnyPublisher()
    }
}

// MARK: - Notification Name Extensions

extension Notification.Name {
    static let qrCodeDetected = Notification.Name("qrCodeDetected")
    static let settingsChanged = Notification.Name("settingsChanged")
}

// MARK: - Global DI Access (Convenience)

/// グローバルなDI解決のためのヘルパー
func resolve<T>(_ type: T.Type) -> T {
    return DIContainer.shared.resolve(type)
}

/// シングルトン解決のためのヘルパー
func resolveSingleton<T>(_ type: T.Type) -> T {
    return DIContainer.shared.resolveSingleton(type)
}