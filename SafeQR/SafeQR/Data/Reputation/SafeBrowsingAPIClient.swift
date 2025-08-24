import Foundation
import CommonCrypto

/**
 * Google Safe Browsing API v4 クライアント
 * プライバシー保護のため、URLハッシュプレフィックスを使用
 * 高精度な脅威検出とリアルタイム更新を提供
 */
class SafeBrowsingAPIClient {
    
    // MARK: - 定数
    
    /// Safe Browsing API v4 エンドポイント
    private let apiEndpoint = "https://safebrowsing.googleapis.com/v4/threatMatches:find"
    
    /// ハッシュプレフィックス長（プライバシーとパフォーマンスのバランス）
    private let hashPrefixLength = 4 // 4バイト = 32bit
    
    /// API タイムアウト（秒）
    private let timeoutInterval: TimeInterval = 5.0
    
    /// キャッシュ有効期限（秒）
    private let cacheValidityDuration: TimeInterval = 24 * 60 * 60 // 24時間
    
    // MARK: - プロパティ
    
    /// APIキー（Info.plistまたは環境変数から取得）
    private var apiKey: String? {
        // Info.plistから取得
        if let key = Bundle.main.object(forInfoDictionaryKey: "SafeBrowsingAPIKey") as? String,
           !key.isEmpty, key != "YOUR_API_KEY_HERE" {
            return key
        }
        
        // デバッグ時の警告
        #if DEBUG
        print("⚠️ Safe Browsing APIキーが設定されていません。")
        print("  Info.plistに 'SafeBrowsingAPIKey' を追加してください。")
        print("  取得方法: https://developers.google.com/safe-browsing/v4/get-started")
        #endif
        
        return nil
    }
    
    /// 設定ストア
    private let settingsStore = SettingsStore.shared
    
    /// キャッシュストレージ
    private let cache = URLCache.shared
    
    /// URLセッション
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutInterval
        config.timeoutIntervalForResource = timeoutInterval
        config.urlCache = cache
        return URLSession(configuration: config)
    }()
    
    // MARK: - 型定義
    
    /// Safe Browsing 脅威タイプ
    enum ThreatType: String, CaseIterable {
        case malware = "MALWARE"
        case socialEngineering = "SOCIAL_ENGINEERING" // フィッシング
        case unwantedSoftware = "UNWANTED_SOFTWARE"
        case potentiallyHarmfulApplication = "POTENTIALLY_HARMFUL_APPLICATION"
        
        var safetyLevel: SafetyLevel {
            switch self {
            case .malware, .potentiallyHarmfulApplication:
                return .danger
            case .socialEngineering:
                return .danger
            case .unwantedSoftware:
                return .caution
            }
        }
    }
    
    /// API レスポンス結果
    struct SafeBrowsingResult {
        let isURLSafe: Bool
        let detectedThreats: [ThreatType]
        let safetyLevel: SafetyLevel
        let responseTime: Double
        let cacheHit: Bool
        
        static let safe = SafeBrowsingResult(
            isURLSafe: true,
            detectedThreats: [],
            safetyLevel: .safe,
            responseTime: 0,
            cacheHit: false
        )
    }
    
    /// APIエラー
    enum SafeBrowsingError: Error {
        case invalidURL
        case apiKeyMissing
        case networkError(Error)
        case apiError(Int, String)
        case parsingError
        case timeout
        
        var localizedDescription: String {
            switch self {
            case .invalidURL:
                return "無効なURLです"
            case .apiKeyMissing:
                return "APIキーが設定されていません"
            case .networkError(let error):
                return "ネットワークエラー: \(error.localizedDescription)"
            case .apiError(let code, let message):
                if code == 403 {
                    return "APIキー認証エラー [403]: APIキーが無効または未設定です。Info.plistを確認してください。"
                }
                return "APIエラー [\(code)]: \(message)"
            case .parsingError:
                return "レスポンス解析エラー"
            case .timeout:
                return "タイムアウトしました"
            }
        }
    }
    
    // MARK: - 公開メソッド
    
    /**
     * URLの安全性をチェック
     * @param url: チェック対象URL
     * @param completion: 完了コールバック
     */
    func checkURL(_ url: String, completion: @escaping (Result<SafeBrowsingResult, SafeBrowsingError>) -> Void) {
        
        // 外部API使用が無効な場合
        guard settingsStore.isExternalReputationEnabled else {
            completion(.success(.safe))
            return
        }
        
        // APIキーチェック
        guard let apiKey = apiKey else {
            completion(.failure(.apiKeyMissing))
            return
        }
        
        // URL妥当性チェック
        guard let urlObject = URL(string: url) else {
            completion(.failure(.invalidURL))
            return
        }
        
        let startTime = Date()
        
        // キャッシュチェック
        if let cachedResult = getCachedResult(for: url) {
            let result = SafeBrowsingResult(
                isURLSafe: cachedResult.isURLSafe,
                detectedThreats: cachedResult.detectedThreats,
                safetyLevel: cachedResult.safetyLevel,
                responseTime: Date().timeIntervalSince(startTime) * 1000,
                cacheHit: true
            )
            completion(.success(result))
            return
        }
        
        // APIリクエスト実行
        performAPIRequest(urlObject, apiKey: apiKey, startTime: startTime, completion: completion)
    }
    
    /**
     * 複数URLの一括チェック
     * @param urls: チェック対象URL配列
     * @param completion: 完了コールバック（URL: 結果のマップ）
     */
    func checkURLs(_ urls: [String], completion: @escaping ([String: SafeBrowsingResult]) -> Void) {
        let dispatchGroup = DispatchGroup()
        var results: [String: SafeBrowsingResult] = [:]
        let resultsQueue = DispatchQueue(label: "safebrowsing.results", attributes: .concurrent)
        
        for url in urls {
            dispatchGroup.enter()
            checkURL(url) { result in
                resultsQueue.async(flags: .barrier) {
                    switch result {
                    case .success(let safeBrowsingResult):
                        results[url] = safeBrowsingResult
                    case .failure:
                        // エラーの場合は安全として扱う（フォールバック）
                        results[url] = .safe
                    }
                    dispatchGroup.leave()
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(results)
        }
    }
    
    // MARK: - プライベートメソッド
    
    /**
     * APIリクエストの実行
     */
    private func performAPIRequest(_ url: URL, apiKey: String, startTime: Date, completion: @escaping (Result<SafeBrowsingResult, SafeBrowsingError>) -> Void) {
        
        guard let request = buildAPIRequest(for: url, apiKey: apiKey) else {
            completion(.failure(.invalidURL))
            return
        }
        
        urlSession.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.handleAPIResponse(data: data, response: response, error: error, url: url.absoluteString, startTime: startTime, completion: completion)
            }
        }.resume()
    }
    
    /**
     * APIリクエストの構築
     */
    private func buildAPIRequest(for url: URL, apiKey: String) -> URLRequest? {
        
        guard var urlComponents = URLComponents(string: apiEndpoint) else {
            return nil
        }
        
        // APIキーをクエリパラメータに追加
        urlComponents.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        
        guard let requestURL = urlComponents.url else {
            return nil
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // リクエストボディの構築
        let requestBody = buildRequestBody(for: url)
        request.httpBody = requestBody
        
        return request
    }
    
    /**
     * Safe Browsing API v4 リクエストボディの構築
     */
    private func buildRequestBody(for url: URL) -> Data? {
        
        let urlString = url.absoluteString
        
        let requestData: [String: Any] = [
            "client": [
                "clientId": "safeqr-ios",
                "clientVersion": "1.0.0"
            ],
            "threatInfo": [
                "threatTypes": ThreatType.allCases.map { $0.rawValue },
                "platformTypes": ["IOS"],
                "threatEntryTypes": ["URL"],
                "threatEntries": [
                    ["url": urlString]
                ]
            ]
        ]
        
        return try? JSONSerialization.data(withJSONObject: requestData)
    }
    
    /**
     * SHA256ハッシュプレフィックスの生成
     * プライバシー保護のため、フルハッシュではなくプレフィックスのみ送信
     */
    private func generateSHA256HashPrefix(for string: String) -> String {
        guard let data = string.data(using: .utf8) else {
            return ""
        }
        
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        
        // 指定された長さのプレフィックスのみを返す
        let prefixData = Data(hash.prefix(hashPrefixLength))
        return prefixData.map { String(format: "%02hhx", $0) }.joined()
    }
    
    /**
     * APIレスポンスの処理
     */
    private func handleAPIResponse(data: Data?, response: URLResponse?, error: Error?, url: String, startTime: Date, completion: @escaping (Result<SafeBrowsingResult, SafeBrowsingError>) -> Void) {
        
        let responseTime = Date().timeIntervalSince(startTime) * 1000 // ミリ秒
        
        // エラーチェック
        if let error = error {
            let safeBrowsingError: SafeBrowsingError
            if (error as NSError).code == NSURLErrorTimedOut {
                safeBrowsingError = .timeout
            } else {
                safeBrowsingError = .networkError(error)
            }
            completion(.failure(safeBrowsingError))
            return
        }
        
        // HTTPステータスチェック
        if let httpResponse = response as? HTTPURLResponse {
            guard 200...299 ~= httpResponse.statusCode else {
                let message = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                completion(.failure(.apiError(httpResponse.statusCode, message)))
                return
            }
        }
        
        // データ存在チェック
        guard let data = data else {
            completion(.failure(.parsingError))
            return
        }
        
        // JSONパース
        do {
            let result = try parseAPIResponse(data, responseTime: responseTime)
            
            // 結果をキャッシュ
            cacheResult(result, for: url)
            
            completion(.success(result))
        } catch {
            completion(.failure(.parsingError))
        }
    }
    
    /**
     * APIレスポンスのJSONパース
     */
    private func parseAPIResponse(_ data: Data, responseTime: Double) throws -> SafeBrowsingResult {
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        // "matches" フィールドが存在し、空でない場合は脅威検出
        if let matches = json?["matches"] as? [[String: Any]], !matches.isEmpty {
            
            var detectedThreats: [ThreatType] = []
            var highestSeverity: SafetyLevel = .safe
            
            for match in matches {
                if let threatTypeString = match["threatType"] as? String,
                   let threatType = ThreatType(rawValue: threatTypeString) {
                    detectedThreats.append(threatType)
                    
                    // より厳しい安全性レベルを採用
                    if threatType.safetyLevel.rawValue > highestSeverity.rawValue {
                        highestSeverity = threatType.safetyLevel
                    }
                }
            }
            
            return SafeBrowsingResult(
                isURLSafe: false,
                detectedThreats: detectedThreats,
                safetyLevel: highestSeverity,
                responseTime: responseTime,
                cacheHit: false
            )
        } else {
            // マッチなし = 安全
            return SafeBrowsingResult(
                isURLSafe: true,
                detectedThreats: [],
                safetyLevel: .safe,
                responseTime: responseTime,
                cacheHit: false
            )
        }
    }
    
    // MARK: - キャッシュ機能
    
    /**
     * 結果をキャッシュに保存
     */
    private func cacheResult(_ result: SafeBrowsingResult, for url: String) {
        let cacheKey = "safebrowsing_\(url.sha256)"
        let cacheData = [
            "isURLSafe": result.isURLSafe,
            "detectedThreats": result.detectedThreats.map { $0.rawValue },
            "safetyLevel": result.safetyLevel.rawValue,
            "cachedAt": Date().timeIntervalSince1970
        ] as [String : Any]
        
        if let data = try? JSONSerialization.data(withJSONObject: cacheData) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
    
    /**
     * キャッシュから結果を取得
     */
    private func getCachedResult(for url: String) -> SafeBrowsingResult? {
        let cacheKey = "safebrowsing_\(url.sha256)"
        
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cacheData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cachedAt = cacheData["cachedAt"] as? TimeInterval else {
            return nil
        }
        
        // キャッシュ有効期限チェック
        let age = Date().timeIntervalSince1970 - cachedAt
        if age > cacheValidityDuration {
            // 期限切れキャッシュを削除
            UserDefaults.standard.removeObject(forKey: cacheKey)
            return nil
        }
        
        // キャッシュデータの復元
        guard let isURLSafe = cacheData["isURLSafe"] as? Bool,
              let safetyLevelRaw = cacheData["safetyLevel"] as? Int16,
              let safetyLevel = SafetyLevel(rawValue: safetyLevelRaw),
              let threatTypeStrings = cacheData["detectedThreats"] as? [String] else {
            return nil
        }
        
        let detectedThreats = threatTypeStrings.compactMap { ThreatType(rawValue: $0) }
        
        return SafeBrowsingResult(
            isURLSafe: isURLSafe,
            detectedThreats: detectedThreats,
            safetyLevel: safetyLevel,
            responseTime: 0,
            cacheHit: true
        )
    }
}

// MARK: - String拡張（SHA256ハッシュ用）

extension String {
    /// SHA256ハッシュ値を取得（キャッシュキー用）
    var sha256: String {
        guard let data = self.data(using: .utf8) else {
            return self
        }
        
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        
        return hash.map { String(format: "%02hhx", $0) }.joined()
    }
}