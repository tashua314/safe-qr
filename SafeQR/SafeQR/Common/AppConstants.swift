import UIKit

/**
 * アプリケーション全体で使用する定数定義
 * - マジックナンバーの排除
 * - 設定値の一元管理
 * - 型安全な定数定義
 */
enum AppConstants {
    
    // MARK: - Network Settings
    
    enum Network {
        /// ネットワークタイムアウト（秒）
        static let timeoutInterval: TimeInterval = 5.0
        
        /// 最大コンテンツ長
        static let maxContentLength = 50_000
        
        /// リトライ回数
        static let maxRetryCount = 3
        
        /// API レスポンス キャッシュ期間（秒）
        static let cacheValidityDuration: TimeInterval = 24 * 60 * 60 // 24時間
    }
    
    // MARK: - History Management
    
    enum History {
        /// 履歴の最大保持件数
        static let maxCount = 50
        
        /// タイトル取得のタイムアウト（秒）
        static let titleFetchTimeout: TimeInterval = 10.0
    }
    
    // MARK: - QR Code Processing
    
    enum QR {
        /// QRコード文字列の最大長
        static let maxLength = 2000
        
        /// URL パスの最大長
        static let maxPathLength = 1000
        
        /// 許可するURLスキーム
        static let allowedSchemes = ["http", "https"]
        
        /// スキャン重複防止の有効期間（秒）
        static let duplicatePreventionDuration: TimeInterval = 2.0
    }
    
    // MARK: - Security Settings
    
    enum Security {
        /// ローカルネットワークアクセスの許可
        static let allowLocalNetwork = false
        
        /// 危険なポート番号（アクセス禁止）
        static let dangerousPorts = [22, 23, 25, 53, 135, 139, 445, 1433, 3389]
        
        /// Safe Browsing API ハッシュプレフィックス長
        static let hashPrefixLength = 4
        
        /// URL評価のスコア閾値
        enum ScoreThresholds {
            static let safe = 1
            static let caution = 3
        }
    }
    
    // MARK: - UI Constants
    
    enum UI {
        /// オーバーレイの角丸半径
        static let overlayCornerRadius: CGFloat = 8
        
        /// オーバーレイの透明度
        static let overlayAlpha: CGFloat = 0.6
        
        /// ボタンのパディング
        static let buttonPadding = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        
        /// アニメーション時間
        static let animationDuration: TimeInterval = 0.3
        
        /// セルの高さ
        static let cellHeight: CGFloat = 80
        
        /// マージン
        static let standardMargin: CGFloat = 16
        static let compactMargin: CGFloat = 8
    }
    
    // MARK: - Colors
    
    enum Colors {
        /// オーバーレイ背景色
        static let overlayBackground = UIColor.black.withAlphaComponent(0.6)
        
        /// 安全色
        static let safeColor = UIColor.systemGreen
        
        /// 注意色  
        static let cautionColor = UIColor.systemOrange
        
        /// 危険色
        static let dangerColor = UIColor.systemRed
        
        /// プライマリテキスト色
        static let primaryText = UIColor.label
        
        /// セカンダリテキスト色
        static let secondaryText = UIColor.secondaryLabel
        
        /// セパレータ色
        static let separator = UIColor.separator
    }
    
    // MARK: - Fonts
    
    enum Fonts {
        /// タイトル用フォント
        static let title = UIFont.systemFont(ofSize: 18, weight: .semibold)
        
        /// 本文用フォント
        static let body = UIFont.systemFont(ofSize: 16, weight: .regular)
        
        /// キャプション用フォント
        static let caption = UIFont.systemFont(ofSize: 14, weight: .regular)
        
        /// ボタン用フォント
        static let button = UIFont.systemFont(ofSize: 16, weight: .medium)
        
        /// 小さなラベル用フォント
        static let small = UIFont.systemFont(ofSize: 12, weight: .regular)
    }
    
    // MARK: - Safe Browsing API
    
    enum SafeBrowsing {
        /// API エンドポイント
        static let apiEndpoint = "https://safebrowsing.googleapis.com/v4/threatMatches:find"
        
        /// クライアント情報
        static let clientId = "safeqr-ios"
        static let clientVersion = "1.0.0"
        
        /// プラットフォーム識別子
        static let platform = "IOS"
        
        /// 脅威エントリタイプ
        static let threatEntryType = "URL"
    }
    
    // MARK: - Debug Settings
    
    #if DEBUG
    enum Debug {
        /// 詳細ログの有効化
        static let verboseLogging = true
        
        /// モックモードの有効化
        static let enableMockMode = false
        
        /// API レスポンス遅延シミュレーション（秒）
        static let mockAPIDelay: TimeInterval = 1.0
    }
    #endif
}

// MARK: - UserDefaults Keys

extension AppConstants {
    enum UserDefaultsKeys {
        static let safetyStrictness = "safety_strictness"
        static let isExternalReputationEnabled = "external_reputation_enabled"  
        static let lightEnabled = "light_enabled"
        static let onboardingCompleted = "onboarding_completed"
    }
}

// MARK: - Notification Names

extension AppConstants {
    enum NotificationNames {
        static let openURLRequested = "openURLRequested"
        static let settingsChanged = "settingsChanged"
        static let historyUpdated = "historyUpdated"
        static let evaluationCompleted = "evaluationCompleted"
    }
}