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
    // QRScannerServiceのベースクラスで実装されているメソッドは、extensionでは重複宣言不要
}

extension EnhancedUrlRiskEvaluator: URLEvaluationServiceProtocol {
    // 既存のメソッドがプロトコルに適合しているので追加実装不要
}

// HistoryRepositoryProtocol適合はHistoryRepositoryクラス内で実装

// HtmlTitleFetcherは既にプロトコルに適合しているため、extensionは不要

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