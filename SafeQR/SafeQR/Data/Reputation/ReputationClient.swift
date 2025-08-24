import Foundation

/**
 * 外部レピュテーション照会クライアント
 * プライバシー保護のため、URL生値は送信せずドメインハッシュのみを送信
 * 現在はモック実装、後で実際のエンドポイントに差し替え
 */
class ReputationClient {
    
    // MARK: - 型定義
    
    /// レピュテーション照会結果
    struct ReputationResult {
        /// 外部サービスからの安全性判定（nilの場合は不明）
        let safetyLevel: SafetyLevel?
        /// 信頼度スコア（0.0-1.0、高いほど信頼性が高い）
        let confidenceScore: Double?
        /// レスポンス時間（ミリ秒）
        let responseTimeMs: Double?
    }
    
    /// エラー種別
    enum ReputationError: Error {
        case networkError(Error) // ネットワークエラー
        case timeout // タイムアウト
        case invalidResponse // 不正なレスポンス
        case serviceUnavailable // サービス利用不可
        
        var localizedDescription: String {
            switch self {
            case .networkError(let error):
                return "ネットワークエラー: \(error.localizedDescription)"
            case .timeout:
                return "タイムアウトしました"
            case .invalidResponse:
                return "無効なレスポンスです"
            case .serviceUnavailable:
                return "サービスが利用できません"
            }
        }
    }
    
    // MARK: - プロパティ
    
    /// 設定ストア（外部照会の有効/無効を管理）
    private let settingsStore = SettingsStore.shared
    
    /// リクエストタイムアウト（秒）
    private let timeoutInterval: TimeInterval = 3.0
    
    /// モック実装用フラグ（本番環境では false に設定）
    private let isMockMode = true
    
    // MARK: - 公開メソッド
    
    /**
     * URLの外部レピュテーションを照会
     * @param url: 照会するURL
     * @param completion: 完了時のコールバック
     */
    func checkReputation(for url: String, completion: @escaping (Result<ReputationResult, ReputationError>) -> Void) {
        
        // 外部照会が無効の場合は即座に完了
        guard settingsStore.isExternalReputationEnabled else {
            completion(.success(ReputationResult(safetyLevel: nil, confidenceScore: nil, responseTimeMs: nil)))
            return
        }
        
        // モック実装の場合
        if isMockMode {
            handleMockRequest(for: url, completion: completion)
            return
        }
        
        // 実際の外部API呼び出し（後で実装）
        handleRealRequest(for: url, completion: completion)
    }
    
    // MARK: - プライベートメソッド - モック実装
    
    /**
     * モック実装での擬似レピュテーション照会
     * テスト用のダミーレスポンスを返す
     * @param url: 照会するURL
     * @param completion: 完了時のコールバック
     */
    private func handleMockRequest(for url: String, completion: @escaping (Result<ReputationResult, ReputationError>) -> Void) {
        
        // リアルな遅延を模擬（100ms-1000ms）
        let delay = Double.random(in: 0.1...1.0)
        
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
            
            // URL内容に基づく擬似判定
            let mockResult = self.generateMockResult(for: url, responseTime: delay * 1000)
            
            // メインスレッドでコールバック実行
            DispatchQueue.main.async {
                completion(.success(mockResult))
            }
        }
    }
    
    /**
     * モック結果の生成
     * URLの特徴に基づいて擬似的な判定結果を作成
     * @param url: 判定するURL
     * @param responseTime: レスポンス時間（ミリ秒）
     * @return: モックのReputationResult
     */
    private func generateMockResult(for url: String, responseTime: Double) -> ReputationResult {
        let lowercaseUrl = url.lowercased()
        
        // 危険なパターンのモック判定
        if lowercaseUrl.contains("phishing") || 
           lowercaseUrl.contains("malware") || 
           lowercaseUrl.contains("suspicious") {
            return ReputationResult(
                safetyLevel: .danger,
                confidenceScore: 0.9,
                responseTimeMs: responseTime
            )
        }
        
        // 注意が必要なパターンのモック判定
        if lowercaseUrl.contains("ads") ||
           lowercaseUrl.contains("tracking") ||
           lowercaseUrl.contains("redirect") {
            return ReputationResult(
                safetyLevel: .caution,
                confidenceScore: 0.7,
                responseTimeMs: responseTime
            )
        }
        
        // 有名サイトのモック判定
        if lowercaseUrl.contains("google.com") ||
           lowercaseUrl.contains("apple.com") ||
           lowercaseUrl.contains("github.com") {
            return ReputationResult(
                safetyLevel: .safe,
                confidenceScore: 0.95,
                responseTimeMs: responseTime
            )
        }
        
        // その他は不明として返す（端末内判定に委ねる）
        return ReputationResult(
            safetyLevel: nil,
            confidenceScore: 0.5,
            responseTimeMs: responseTime
        )
    }
    
    // MARK: - プライベートメソッド - 実装予定の外部API呼び出し
    
    /**
     * 実際の外部レピュテーションAPI呼び出し
     * 現在は未実装、後で実際のエンドポイントを実装
     * @param url: 照会するURL
     * @param completion: 完了時のコールバック
     */
    private func handleRealRequest(for url: String, completion: @escaping (Result<ReputationResult, ReputationError>) -> Void) {
        
        // プライバシー保護：ドメインのハッシュ値のみを送信
        let domainHash = generateDomainHash(from: url)
        
        // 実際のAPI設定（後で実装）
        guard let apiEndpoint = buildApiEndpoint(domainHash: domainHash) else {
            completion(.failure(.serviceUnavailable))
            return
        }
        
        // URLSession設定
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutInterval
        let session = URLSession(configuration: config)
        
        // リクエスト作成
        var request = URLRequest(url: apiEndpoint)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // APIキーがある場合は設定（環境変数から取得）
        if let apiKey = getApiKey() {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        let startTime = Date()
        
        // API呼び出し実行
        session.dataTask(with: request) { data, response, error in
            let responseTime = Date().timeIntervalSince(startTime) * 1000 // ミリ秒
            
            DispatchQueue.main.async {
                // エラーハンドリング
                if let error = error {
                    if (error as NSError).code == NSURLErrorTimedOut {
                        completion(.failure(.timeout))
                    } else {
                        completion(.failure(.networkError(error)))
                    }
                    return
                }
                
                // レスポンス解析
                guard let data = data,
                      let result = self.parseApiResponse(data, responseTime: responseTime) else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                completion(.success(result))
            }
        }.resume()
    }
    
    /**
     * ドメインハッシュの生成
     * プライバシー保護のため、URL全体ではなくドメインのハッシュのみを送信
     * @param url: 元のURL
     * @return: ドメインのハッシュ値
     */
    private func generateDomainHash(from url: String) -> String {
        // URLからドメインを抽出
        guard let urlObject = URL(string: url),
              let host = urlObject.host else {
            return url.sha256 // URLが不正な場合は全体をハッシュ
        }
        
        // ドメインのハッシュを生成
        return host.sha256
    }
    
    /**
     * API エンドポイントのURL構築
     * @param domainHash: ドメインのハッシュ値
     * @return: APIエンドポイントのURL
     */
    private func buildApiEndpoint(domainHash: String) -> URL? {
        // 実際のエンドポイントに置き換える
        let baseUrl = "https://api.example.com/v1/reputation"
        let urlString = "\(baseUrl)?domain_hash=\(domainHash)"
        return URL(string: urlString)
    }
    
    /**
     * APIキーの取得
     * 設定ファイルや環境変数から取得
     * @return: APIキー（設定されていない場合はnil）
     */
    private func getApiKey() -> String? {
        // Info.plistまたは設定ファイルからAPIキーを取得
        return Bundle.main.object(forInfoDictionaryKey: "ReputationAPIKey") as? String
    }
    
    /**
     * API レスポンスの解析
     * @param data: レスポンスデータ
     * @param responseTime: レスポンス時間（ミリ秒）
     * @return: 解析されたReputationResult
     */
    private func parseApiResponse(_ data: Data, responseTime: Double) -> ReputationResult? {
        do {
            // JSON解析（実際のAPIレスポンス形式に合わせて実装）
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            // 安全性レベルの解析
            var safetyLevel: SafetyLevel?
            if let levelString = json?["safety_level"] as? String {
                switch levelString.lowercased() {
                case "safe":
                    safetyLevel = .safe
                case "caution", "warning":
                    safetyLevel = .caution
                case "danger", "malicious":
                    safetyLevel = .danger
                default:
                    safetyLevel = nil
                }
            }
            
            // 信頼度スコアの解析
            let confidenceScore = json?["confidence"] as? Double
            
            return ReputationResult(
                safetyLevel: safetyLevel,
                confidenceScore: confidenceScore,
                responseTimeMs: responseTime
            )
            
        } catch {
            print("APIレスポンス解析エラー: \(error)")
            return nil
        }
    }
}

// MARK: - String拡張（ハッシュ生成用）
// SHA256拡張はSafeBrowsingAPIClientで定義済みのため削除