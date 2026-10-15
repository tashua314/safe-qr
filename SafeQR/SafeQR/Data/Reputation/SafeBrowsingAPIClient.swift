import CryptoKit
import Foundation

/// v5 hashes.searchへSHA-256の4バイトprefixだけを送り、完全ハッシュは端末で照合する。
class SafeBrowsingAPIClient {
    struct Configuration {
        var apiKey: () -> String? = {
            guard let key = Bundle.main.object(forInfoDictionaryKey: "SafeBrowsingAPIKey") as? String,
                  !key.isEmpty, key != "YOUR_API_KEY_HERE" else { return nil }
            return key
        }

        var externalEnabled: () -> Bool = { SettingsStore.shared.isExternalReputationEnabled }
        var suffixList: PublicSuffixList? = .bundled
        var now: () -> Date = Date.init
    }

    private let configuration: Configuration
    private let session: URLSession
    private let cache = SafeBrowsingHashCache()
    private let endpoint = "https://safebrowsing.googleapis.com/v5/hashes:search"

    init(configuration: Configuration = Configuration(), session: URLSession? = nil) {
        self.configuration = configuration
        if let session = session {
            self.session = session
        } else {
            let settings = URLSessionConfiguration.ephemeral
            settings.timeoutIntervalForRequest = 5
            settings.timeoutIntervalForResource = 5
            settings.urlCache = nil
            settings.httpCookieStorage = nil
            settings.httpShouldSetCookies = false
            self.session = URLSession(configuration: settings, delegate: SafeBrowsingSessionDelegate(), delegateQueue: nil)
        }
    }

    enum ThreatType: String, CaseIterable {
        case malware = "MALWARE"
        case socialEngineering = "SOCIAL_ENGINEERING"
        case unwantedSoftware = "UNWANTED_SOFTWARE"
        case potentiallyHarmfulApplication = "POTENTIALLY_HARMFUL_APPLICATION"

        var safetyLevel: SafetyLevel {
            self == .unwantedSoftware ? .caution : .danger
        }
    }

    typealias CheckResult = Result<SafeBrowsingResult, SafeBrowsingError>

    struct SafeBrowsingResult {
        enum VerificationStatus { case noMatch, threats, unrecognizedThreats }
        let verificationStatus: VerificationStatus
        let detectedThreats: [ThreatType]
        let responseTime: Double
        let cacheHit: Bool

        var isURLSafe: Bool {
            verificationStatus == .noMatch
        }

        var safetyLevel: SafetyLevel? {
            if verificationStatus == .unrecognizedThreats, detectedThreats.isEmpty { return nil }
            return detectedThreats.map(\.safetyLevel).max { $0.rawValue < $1.rawValue } ?? .safe
        }

        static let safe = SafeBrowsingResult(verificationStatus: .noMatch, detectedThreats: [], responseTime: 0, cacheHit: false)
    }

    enum SafeBrowsingError: Error {
        case invalidURL
        case apiKeyMissing
        case networkError(Error)
        case apiError(Int, String)
        case parsingError
        case timeout
        case suffixListUnavailable
        case cacheExpired
        case disabled

        var localizedDescription: String {
            switch self {
            case .invalidURL: return "無効なURLです"
            case .apiKeyMissing: return "APIキーが設定されていません"
            case let .networkError(error): return "ネットワークエラー: \(error.localizedDescription)"
            case let .apiError(code, message): return "APIエラー [\(code)]: \(message)"
            case .parsingError: return "レスポンス解析エラー"
            case .timeout: return "タイムアウトしました"
            case .suffixListUnavailable: return "URL判定用リソースが読み込めません"
            case .cacheExpired: return "外部判定の有効期限が切れました"
            case .disabled: return "外部チェックは無効です"
            }
        }
    }

    func checkURL(_ url: String, completion: @escaping (Result<SafeBrowsingResult, SafeBrowsingError>) -> Void) {
        guard configuration.externalEnabled() else { completion(.failure(.disabled))
            return
        }
        guard let key = configuration.apiKey() else { completion(.failure(.apiKeyMissing))
            return
        }
        guard let suffixList = configuration.suffixList else { completion(.failure(.suffixListUnavailable))
            return
        }
        let fullHashes: Set<Data>
        do {
            fullHashes = try SafeBrowsingURLHasher(suffixList: suffixList).fullHashes(for: url)
        } catch {
            completion(.failure(.invalidURL))
            return
        }
        let start = configuration.now()
        let prefixes = Set(fullHashes.map { Data($0.prefix(4)) })
        let cached = cache.lookup(prefixes, now: start)
        if cached.missing.isEmpty {
            completion(.success(evaluate(cached.hashes, candidates: fullHashes, start: start, cacheHit: true)))
            return
        }
        guard let request = makeRequest(prefixes: cached.missing, key: key) else { completion(.failure(.invalidURL))
            return
        }
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                let result = self.handleResponse(data: data, response: response, error: error, prefixes: cached.missing)
                completion(result.flatMap { hashes in
                    let freshCache = self.cache.lookup(prefixes.subtracting(cached.missing), now: self.configuration.now())
                    guard freshCache.missing.isEmpty else { return .failure(.cacheExpired) }
                    return .success(self.evaluate(freshCache.hashes + hashes, candidates: fullHashes, start: start, cacheHit: false))
                })
            }
        }.resume()
    }

    func checkURLs(_ urls: [String], completion: @escaping ([String: CheckResult]) -> Void) {
        let group = DispatchGroup()
        let lock = NSLock()
        var results = [String: CheckResult]()
        for url in urls {
            group.enter()
            checkURL(url) { result in
                lock.lock()
                results[url] = result
                lock.unlock()
                group.leave()
            }
        }
        group.notify(queue: .main) { completion(results) }
    }

    private func makeRequest(prefixes: Set<Data>, key: String) -> URLRequest? {
        guard var components = URLComponents(string: endpoint) else { return nil }
        components.queryItems = [URLQueryItem(name: "key", value: key)] + prefixes.sorted { $0.lexicographicallyPrecedes($1) }.map {
            URLQueryItem(name: "hashPrefixes", value: $0.base64EncodedString())
        }
        // URLComponentsは「+」をそのまま残すが、gRPC queryはフォームとして復号する。
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = "GET"
        return request
    }

    private struct HashResponse: Decodable {
        let fullHashes: [SafeBrowsingHashCache.FullHash]
        let cacheDuration: String

        private enum CodingKeys: String, CodingKey { case fullHashes, cacheDuration }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            // protobuf JSONは空repeated fieldを省略できるが、null/誤った型は成功にしない。
            fullHashes = container.contains(.fullHashes) ? try container
                .decode([SafeBrowsingHashCache.FullHash].self, forKey: .fullHashes) : []
            cacheDuration = try container.decode(String.self, forKey: .cacheDuration)
        }
    }

    private func handleResponse(
        data: Data?, response: URLResponse?, error: Error?, prefixes: Set<Data>
    ) -> Result<[SafeBrowsingHashCache.FullHash], SafeBrowsingError> {
        if let error = error {
            return .failure((error as NSError).code == NSURLErrorTimedOut ? .timeout : .networkError(error))
        }
        guard let response = response as? HTTPURLResponse else { return .failure(.parsingError) }
        guard response.statusCode == 200 else {
            return .failure(.apiError(response.statusCode, HTTPURLResponse.localizedString(forStatusCode: response.statusCode)))
        }
        guard let data = data, let parsed = try? JSONDecoder().decode(HashResponse.self, from: data),
              let duration = parseCacheDuration(parsed.cacheDuration) else { return .failure(.parsingError) }
        let hashes = parsed.fullHashes
        guard hashes.allSatisfy({ hash in
            hash.fullHash.count == 32 && prefixes.contains(Data(hash.fullHash.prefix(4)))
                && !hash.fullHashDetails.isEmpty && hash.fullHashDetails.allSatisfy { !$0.threatType.isEmpty }
        }) else {
            return .failure(.parsingError)
        }
        cache.store(hashes, prefixes: prefixes, duration: duration, now: configuration.now())
        return .success(hashes)
    }

    private func parseCacheDuration(_ text: String) -> TimeInterval? {
        guard text.range(of: "^[0-9]+(?:\\.[0-9]{1,9})?s$", options: .regularExpression) != nil else { return nil }
        let components = text.dropLast().split(separator: ".")
        // protobuf Durationの秒数上限とUInt64 overflowを確認し、不正TTLをcacheしない。
        guard let integer = components.first, let seconds = UInt64(integer), seconds <= 315_576_000_000 else { return nil }
        return Double(text.dropLast())
    }

    private func evaluate(
        _ hashes: [SafeBrowsingHashCache.FullHash],
        candidates: Set<Data>,
        start: Date,
        cacheHit: Bool
    ) -> SafeBrowsingResult {
        var threats = Set<ThreatType>()
        var hasUnknown = false
        for hash in hashes where candidates.contains(hash.fullHash) {
            for detail in hash.fullHashDetails {
                let knownAttributes: Set = ["CANARY", "FRAME_ONLY"]
                guard let threat = ThreatType(rawValue: detail.threatType),
                      detail.attributes.allSatisfy({ knownAttributes.contains($0) }) else {
                    hasUnknown = true // 未対応detail全体を適用しない。安全としても扱わない。
                    continue
                }
                if detail.attributes.isEmpty { threats.insert(threat) }
            }
        }
        let status: SafeBrowsingResult.VerificationStatus = hasUnknown ? .unrecognizedThreats : (threats.isEmpty ? .noMatch : .threats)
        return SafeBrowsingResult(
            verificationStatus: status, detectedThreats: threats.sorted { $0.rawValue < $1.rawValue },
            responseTime: configuration.now().timeIntervalSince(start) * 1000, cacheHit: cacheHit
        )
    }
}

private final class SafeBrowsingSessionDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _: URLSession, task _: URLSessionTask, willPerformHTTPRedirection _: HTTPURLResponse,
        newRequest _: URLRequest, completionHandler: @escaping (URLRequest?) -> Void
    ) {
        // キーとhash prefixを別の送信先へ転送しない。
        completionHandler(nil)
    }
}

extension String {
    var sha256: String {
        SHA256.hash(data: Data(utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
