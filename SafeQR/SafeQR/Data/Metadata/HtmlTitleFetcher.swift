import Foundation

/**
 * HTMLページからタイトルを取得するクライアント
 * タイムアウトを短く設定し、レスポンスが遅いサイトでもアプリがブロックされないように配慮
 * 履歴表示用のタイトル取得に使用
 */
class HtmlTitleFetcher: HtmlTitleFetcherProtocol {
    // MARK: - 型定義

    /// タイトル取得結果
    struct TitleFetchResult {
        /// 取得したタイトル（取得失敗時はnil）
        let title: String?
        /// タイトル取得にかかった時間（ミリ秒）
        let fetchTimeMs: Double
        /// 取得成功/失敗
        let isSuccess: Bool
    }

    /// エラー種別
    enum TitleFetchError: Error {
        case networkError(Error) // ネットワークエラー
        case timeout // タイムアウト
        case invalidResponse // 不正なレスポンス
        case titleNotFound // タイトルタグが見つからない
        case invalidUrl // 無効なURL

        var localizedDescription: String {
            switch self {
            case let .networkError(error):
                return "ネットワークエラー: \(error.localizedDescription)"
            case .timeout:
                return "タイムアウトしました"
            case .invalidResponse:
                return "無効なレスポンスです"
            case .titleNotFound:
                return "タイトルが見つかりませんでした"
            case .invalidUrl:
                return "無効なURLです"
            }
        }
    }

    // MARK: - プロパティ

    /// リクエストタイムアウト（秒）
    /// 短く設定してアプリの応答性を保つ
    private let timeoutInterval: TimeInterval = 5.0

    /// 取得する最大データサイズ（バイト）
    /// 大きなページでメモリを消費しすぎないよう制限
    private let maxContentLength: Int = 50000 // 50KB

    private let sessionConfiguration: URLSessionConfiguration

    init(sessionConfiguration: URLSessionConfiguration = .ephemeral) {
        self.sessionConfiguration = sessionConfiguration
    }

    // MARK: - 公開メソッド

    /**
     * URLからHTMLタイトルを取得
     * @param url: タイトルを取得するURL
     * @param completion: 完了時のコールバック（メインスレッドで実行）
     */
    func fetchTitle(from url: String, completion: @escaping (Result<TitleFetchResult, TitleFetchError>) -> Void) {
        // URL妥当性チェック
        guard let urlObject = URL(string: url) else {
            DispatchQueue.main.async {
                completion(.failure(.invalidUrl))
            }
            return
        }

        // HTTPSまたはHTTPのみ許可
        guard let scheme = urlObject.scheme,
              scheme == "http" || scheme == "https" else {
            DispatchQueue.main.async {
                completion(.failure(.invalidUrl))
            }
            return
        }

        let startTime = Date()

        // URLSession設定
        let config = (sessionConfiguration.copy() as? URLSessionConfiguration) ?? .ephemeral
        config.urlCache = nil
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.timeoutIntervalForRequest = timeoutInterval
        config.timeoutIntervalForResource = timeoutInterval

        // ヘッダー設定（軽量化とUser-Agent設定）
        config.httpAdditionalHeaders = [
            "User-Agent": "SafeQR/1.0 (iOS QR Scanner)",
            "Accept": "text/html,application/xhtml+xml",
            "Accept-Language": "ja,en;q=0.9",
            "Accept-Encoding": "gzip, deflate"
        ]

        let session = URLSession(configuration: config, delegate: HtmlTitleSessionDelegate(), delegateQueue: nil)

        // リクエスト作成
        var request = URLRequest(url: urlObject)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData // キャッシュを無視して最新を取得

        // データタスク実行
        session.dataTask(with: request) { [weak self] data, response, error in
            session.finishTasksAndInvalidate()
            let fetchTime = Date().timeIntervalSince(startTime) * 1000 // ミリ秒

            // メインスレッドでコールバック実行
            DispatchQueue.main.async {
                self?.handleResponse(data: data, response: response, error: error, fetchTime: fetchTime, completion: completion)
            }
        }.resume()
    }

    // MARK: - Protocol Conformance

    /**
     * プロトコル適合のため、簡潔な形式でタイトルを取得
     */
    func fetchTitle(from url: String, completion: @escaping (Result<String, Error>) -> Void) {
        fetchTitle(from: url) { result in
            switch result {
            case let .success(titleResult):
                if let title = titleResult.title {
                    completion(.success(title))
                } else {
                    completion(.failure(TitleFetchError.titleNotFound))
                }
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    /**
     * 複数URLから並行してタイトルを取得
     * @param urls: タイトルを取得するURL配列
     * @param completion: 全て完了時のコールバック（URL: 結果の辞書）
     */
    func fetchTitles(from urls: [String], completion: @escaping ([String: TitleFetchResult]) -> Void) {
        guard !urls.isEmpty else {
            DispatchQueue.main.async {
                completion([:])
            }
            return
        }

        let dispatchGroup = DispatchGroup()
        var results: [String: TitleFetchResult] = [:]
        let resultsQueue = DispatchQueue(label: "title.fetch.results", attributes: .concurrent)

        // 並行実行
        for url in urls {
            dispatchGroup.enter()

            fetchTitle(from: url) { result in
                resultsQueue.async(flags: .barrier) {
                    switch result {
                    case let .success(titleResult):
                        results[url] = titleResult
                    case .failure:
                        // エラーの場合は失敗結果を格納
                        results[url] = TitleFetchResult(title: nil, fetchTimeMs: 0, isSuccess: false)
                    }

                    dispatchGroup.leave()
                }
            }
        }

        // 全て完了時にコールバック実行
        dispatchGroup.notify(queue: .main) {
            completion(results)
        }
    }

    // MARK: - プライベートメソッド

    /**
     * レスポンス処理
     * @param data: レスポンスデータ
     * @param response: HTTPレスポンス
     * @param error: エラー
     * @param fetchTime: 取得時間（ミリ秒）
     * @param completion: 完了コールバック
     */
    private func handleResponse(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        fetchTime: Double,
        completion: @escaping (Result<TitleFetchResult, TitleFetchError>) -> Void
    ) {
        // エラーチェック
        if let error = error {
            let titleFetchError: TitleFetchError

            if (error as NSError).code == NSURLErrorTimedOut {
                titleFetchError = .timeout
            } else {
                titleFetchError = .networkError(error)
            }

            completion(.failure(titleFetchError))
            return
        }

        // レスポンスデータチェック
        guard let data = data else {
            completion(.failure(.invalidResponse))
            return
        }

        // HTTPステータスコードチェック
        if let httpResponse = response as? HTTPURLResponse {
            guard 200 ... 299 ~= httpResponse.statusCode else {
                completion(.failure(.invalidResponse))
                return
            }
        }

        // データサイズ制限チェック
        guard data.count <= maxContentLength else {
            // データが大きすぎる場合は先頭部分のみ使用
            let limitedData = data.prefix(maxContentLength)
            processHtmlData(Data(limitedData), fetchTime: fetchTime, completion: completion)
            return
        }

        processHtmlData(data, fetchTime: fetchTime, completion: completion)
    }

    /**
     * HTMLデータからタイトルを抽出
     * @param data: HTMLデータ
     * @param fetchTime: 取得時間（ミリ秒）
     * @param completion: 完了コールバック
     */
    private func processHtmlData(
        _ data: Data,
        fetchTime: Double,
        completion: @escaping (Result<TitleFetchResult, TitleFetchError>) -> Void
    ) {
        // HTML文字列に変換
        guard let htmlString = extractStringFromData(data) else {
            completion(.failure(.invalidResponse))
            return
        }

        // タイトル抽出
        if let title = extractTitle(from: htmlString) {
            let result = TitleFetchResult(
                title: title,
                fetchTimeMs: fetchTime,
                isSuccess: true
            )
            completion(.success(result))
        } else {
            let result = TitleFetchResult(
                title: nil,
                fetchTimeMs: fetchTime,
                isSuccess: false
            )
            completion(.success(result)) // タイトルがないのはエラーではない
        }
    }

    /**
     * DataからStringに変換（エンコーディング自動判定）
     * @param data: 変換するData
     * @return: 変換された文字列（失敗時はnil）
     */
    private func extractStringFromData(_ data: Data) -> String? {
        // UTF-8を最初に試す
        if let string = String(data: data, encoding: .utf8) {
            return string
        }

        // Shift_JISを試す（日本語サイト対応）
        let shiftJIS = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.shiftJIS.rawValue))
        if let string = String(data: data, encoding: String.Encoding(rawValue: shiftJIS)) {
            return string
        }

        // EUC-JPを試す
        let eucJP = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.EUC_JP.rawValue))
        if let string = String(data: data, encoding: String.Encoding(rawValue: eucJP)) {
            return string
        }

        // ISO Latin 1（ASCII互換）を試す
        if let string = String(data: data, encoding: .isoLatin1) {
            return string
        }

        return nil
    }

    /**
     * HTML文字列からタイトルを抽出
     * 正規表現を使用してtitleタグの内容を取得
     * @param html: HTML文字列
     * @return: 抽出されたタイトル（見つからない場合はnil）
     */
    private func extractTitle(from html: String) -> String? {
        // タイトルタグの正規表現パターン（大文字小文字を区別しない）
        let patterns = [
            "<title[^>]*>([^<]+)</title>", // 基本パターン
            "<title[^>]*>\\s*([^<\\s][^<]*?)\\s*</title>" // 前後空白を除去
        ]

        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
                let range = NSRange(location: 0, length: html.count)

                if let match = regex.firstMatch(in: html, options: [], range: range) {
                    let titleRange = match.range(at: 1) // 1番目のキャプチャグループ

                    if titleRange.location != NSNotFound {
                        let title = (html as NSString).substring(with: titleRange)
                        let cleanedTitle = cleanTitle(title)

                        if !cleanedTitle.isEmpty {
                            return cleanedTitle
                        }
                    }
                }

            } catch {
                print("正規表現エラー: \(error)")
                continue
            }
        }

        return nil
    }

    /**
     * タイトル文字列のクリーンアップ
     * HTMLエンティティのデコードや不要な文字の除去
     * @param title: 元のタイトル文字列
     * @return: クリーンアップされたタイトル
     */
    private func cleanTitle(_ title: String) -> String {
        var cleaned = title

        // 前後の空白を除去
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // HTMLエンティティのデコード（基本的なもののみ）
        let entityMap: [String: String] = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&#39;": "'",
            "&nbsp;": " "
        ]

        for (entity, replacement) in entityMap {
            cleaned = cleaned.replacingOccurrences(of: entity, with: replacement)
        }

        // 連続する空白を単一の空白に変換
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        // 最大長制限（表示用）
        if cleaned.count > 100 {
            let endIndex = cleaned.index(cleaned.startIndex, offsetBy: 97)
            cleaned = String(cleaned[..<endIndex]) + "..."
        }

        return cleaned
    }
}

/// 開封許可は元URLに限る。未評価のリダイレクト先へタイトル取得を転送しない。
final class HtmlTitleSessionDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _: URLSession, task _: URLSessionTask, willPerformHTTPRedirection _: HTTPURLResponse,
        newRequest _: URLRequest, completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
