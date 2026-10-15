import Foundation

/**
 * 強化版URL危険度評価エンジン
 * ローカル評価 + Google Safe Browsing API のハイブリッド方式
 * 高精度とプライバシー保護を両立
 */
class EnhancedUrlRiskEvaluator {
    // MARK: - プロパティ

    /// ローカル評価エンジン
    private let localEvaluator = UrlRiskEvaluator()

    /// Safe Browsing API クライアント
    private let safeBrowsingClient = SafeBrowsingAPIClient()

    /// 設定ストア
    private let settingsStore = SettingsStore.shared

    // MARK: - 型定義

    /// 評価結果の詳細情報
    struct EvaluationResult {
        let finalSafetyLevel: SafetyLevel
        let localResult: SafetyLevel
        let apiResult: SafeBrowsingAPIClient.SafeBrowsingResult?
        let evaluationMethod: EvaluationMethod
        let responseTime: Double

        enum EvaluationMethod {
            case localOnly // ローカル評価のみ
            case hybridImmediate // ローカル即座 + API後続
            case hybridCached // キャッシュヒット
            case localFallback // API失敗時ローカルフォールバック
        }
    }

    // MARK: - 公開メソッド

    /**
     * URL危険度評価（即座レスポンス版）
     * ローカル評価結果を即座に返し、API評価は非同期で実行
     * @param url: 評価対象URL
     * @param completion: API評価完了時のコールバック（オプション）
     * @return: ローカル評価結果（即座）
     */
    func evaluateImmediate(url: String, completion: ((EvaluationResult) -> Void)? = nil) -> SafetyLevel {
        let startTime = Date()

        // 1. ローカル詳細評価（即座実行）
        let localDetailedResult = localEvaluator.evaluateWithDetails(url: url)
        let localResult = localDetailedResult.finalSafetyLevel

        // 2. ローカル評価で危険と判定された場合は即座にブロック
        if localResult == .danger {
            let result = EvaluationResult(
                finalSafetyLevel: .danger,
                localResult: localResult,
                apiResult: nil,
                evaluationMethod: .localOnly,
                responseTime: Date().timeIntervalSince(startTime) * 1000
            )
            completion?(result)
            return .danger
        }

        // 3. API評価を非同期で実行（バックグラウンド）
        if settingsStore.isExternalReputationEnabled {
            safeBrowsingClient.checkURL(url) { [weak self] apiResultWrapper in
                self?.handleAPIResult(apiResultWrapper, localResult: localResult, startTime: startTime, completion: completion)
            }
        }

        // 4. まずローカル結果を返す（UX重視）
        return localResult
    }

    /**
     * URL危険度評価（完全同期版）
     * ローカル + API の両方完了まで待機
     * @param url: 評価対象URL
     * @param completion: 完了コールバック
     */
    func evaluateComplete(url: String, completion: @escaping (EvaluationResult) -> Void) {
        let startTime = Date()

        // ローカル詳細評価
        let localDetailedResult = localEvaluator.evaluateWithDetails(url: url)
        let localResult = localDetailedResult.finalSafetyLevel

        // ローカル評価で危険な場合は即座に返す
        if localResult == .danger {
            let result = EvaluationResult(
                finalSafetyLevel: .danger,
                localResult: localResult,
                apiResult: nil,
                evaluationMethod: .localOnly,
                responseTime: Date().timeIntervalSince(startTime) * 1000
            )
            completion(result)
            return
        }

        // API評価実行
        if settingsStore.isExternalReputationEnabled {
            safeBrowsingClient.checkURL(url) { [weak self] apiResultWrapper in
                self?.handleAPIResult(apiResultWrapper, localResult: localResult, startTime: startTime, completion: completion)
            }
        } else {
            // API無効時はローカル結果のみ
            let result = EvaluationResult(
                finalSafetyLevel: localResult,
                localResult: localResult,
                apiResult: nil,
                evaluationMethod: .localOnly,
                responseTime: Date().timeIntervalSince(startTime) * 1000
            )
            completion(result)
        }
    }

    /**
     * 複数URL一括評価
     * @param urls: 評価対象URL配列
     * @param completion: 完了コールバック
     */
    func evaluateMultiple(urls: [String], completion: @escaping ([String: EvaluationResult]) -> Void) {
        let dispatchGroup = DispatchGroup()
        var results: [String: EvaluationResult] = [:]
        let resultsQueue = DispatchQueue(label: "evaluation.results", attributes: .concurrent)

        for url in urls {
            dispatchGroup.enter()
            evaluateComplete(url: url) { result in
                resultsQueue.async(flags: .barrier) {
                    results[url] = result
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
     * API結果の処理とファイナル判定
     */
    private func handleAPIResult(
        _ apiResultWrapper: Result<SafeBrowsingAPIClient.SafeBrowsingResult, SafeBrowsingAPIClient.SafeBrowsingError>,
        localResult: SafetyLevel,
        startTime: Date,
        completion: ((EvaluationResult) -> Void)?
    ) {
        let totalResponseTime = Date().timeIntervalSince(startTime) * 1000

        switch apiResultWrapper {
        case let .success(apiResult):
            // 最終的な安全性レベルを決定（より厳格な方を採用）
            let finalSafetyLevel = selectStricterSafetyLevel(local: localResult, api: apiResult.safetyLevel)

            let evaluationMethod: EvaluationResult.EvaluationMethod = apiResult.cacheHit ? .hybridCached : .hybridImmediate

            let result = EvaluationResult(
                finalSafetyLevel: finalSafetyLevel,
                localResult: localResult,
                apiResult: apiResult,
                evaluationMethod: evaluationMethod,
                responseTime: totalResponseTime
            )

            completion?(result)

        case let .failure(error):
            // API失敗時はローカル評価にフォールバック
            print("Safe Browsing API Error: \(error.localizedDescription)")

            let result = EvaluationResult(
                finalSafetyLevel: localResult,
                localResult: localResult,
                apiResult: nil,
                evaluationMethod: .localFallback,
                responseTime: totalResponseTime
            )

            completion?(result)
        }
    }

    /**
     * より厳格な安全性レベルを選択
     * API結果とローカル結果を比較し、より危険度の高い方を採用
     */
    private func selectStricterSafetyLevel(local: SafetyLevel, api: SafetyLevel) -> SafetyLevel {
        // 危険度の数値比較（.danger > .caution > .safe）
        return local.rawValue >= api.rawValue ? local : api
    }
}

// MARK: - 後方互換性サポート

extension EnhancedUrlRiskEvaluator {
    /**
     * 従来のevaluate(url:)メソッドとの互換性維持
     * 即座評価を実行し、ローカル結果を返す
     */
    func evaluate(url: String) -> SafetyLevel {
        return evaluateImmediate(url: url)
    }
}
