import CommonCrypto
import Foundation

class UrlRiskEvaluator {
    private let settingsStore = SettingsStore.shared

    // MARK: - 詳細評価結果の型定義

    /// 評価詳細結果
    struct DetailedEvaluationResult {
        let finalSafetyLevel: SafetyLevel
        let totalScore: Int
        let detectedIssues: [EvaluationIssue]
        let recommendedAction: String

        struct EvaluationIssue {
            let category: IssueCategory
            let description: String
            let score: Int
            let details: String?

            enum IssueCategory {
                case punycodeDetected
                case suspiciousCharacters
                case ipAddressAccess
                case deepSubdomain
                case longPathQuery
                case brandSpoofing
                case suspiciousTLD

                var displayName: String {
                    switch self {
                    case .punycodeDetected:
                        return "国際化ドメイン"
                    case .suspiciousCharacters:
                        return "疑わしい文字"
                    case .ipAddressAccess:
                        return "IPアドレス直接アクセス"
                    case .deepSubdomain:
                        return "深いサブドメイン"
                    case .longPathQuery:
                        return "長いパス/クエリ"
                    case .brandSpoofing:
                        return "ブランド偽装の疑い"
                    case .suspiciousTLD:
                        return "疑わしいドメイン"
                    }
                }

                var emoji: String {
                    switch self {
                    case .punycodeDetected, .suspiciousCharacters, .brandSpoofing:
                        return "🔴"
                    case .ipAddressAccess, .suspiciousTLD:
                        return "🟠"
                    case .deepSubdomain, .longPathQuery:
                        return "🟡"
                    }
                }
            }
        }
    }

    /**
     * URL危険度評価（詳細情報付き）
     * @param url: 評価対象URL
     * @return: 詳細評価結果
     */
    func evaluateWithDetails(url: String) -> DetailedEvaluationResult {
        // 評価器は履歴などからも呼ばれるため、スキャナー入口の検証だけに依存しない。
        guard let components = URLComponents(string: url),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host, !host.isEmpty,
              let urlObject = components.url else {
            return DetailedEvaluationResult(
                finalSafetyLevel: .danger,
                totalScore: 999,
                detectedIssues: [
                    DetailedEvaluationResult.EvaluationIssue(
                        category: .suspiciousCharacters,
                        description: "無効なURL形式",
                        score: 999,
                        details: "URLの形式が不正です"
                    )
                ],
                recommendedAction: "このリンクにはアクセスしないでください"
            )
        }

        var totalScore = 0
        var detectedIssues: [DetailedEvaluationResult.EvaluationIssue] = []

        // 各チェック項目を実行し、詳細情報を収集

        // 1. Punycode/紛らわしい文字混在チェック
        let suspiciousCharResult = checkSuspiciousCharactersDetailed(url: urlObject)
        if let issue = suspiciousCharResult {
            totalScore += issue.score
            detectedIssues.append(issue)
        }

        // 2. IP直打ちチェック
        let ipResult = checkDirectIPAccessDetailed(url: urlObject)
        if let issue = ipResult {
            totalScore += issue.score
            detectedIssues.append(issue)
        }

        // 3. サブドメイン深さチェック
        let subdomainResult = checkSubdomainDepthDetailed(url: urlObject)
        if let issue = subdomainResult {
            totalScore += issue.score
            detectedIssues.append(issue)
        }

        // 4. パス/クエリ長チェック
        let pathResult = checkPathQueryLengthDetailed(url: urlObject)
        if let issue = pathResult {
            totalScore += issue.score
            detectedIssues.append(issue)
        }

        // 5. ブランド語チェック
        let brandResult = checkBrandSpoofingDetailed(url: urlObject)
        if let issue = brandResult {
            totalScore += issue.score
            detectedIssues.append(issue)
        }

        // 6. 疑義TLDチェック
        let tldResult = checkSuspiciousTLDDetailed(url: urlObject)
        if let issue = tldResult {
            totalScore += issue.score
            detectedIssues.append(issue)
        }

        // 厳しさ設定による調整
        totalScore = max(0, totalScore + settingsStore.safetyStrictness.scoreModifier)

        // SafetyLevelに変換
        let safetyLevel: SafetyLevel
        switch totalScore {
        case 0 ... 1:
            safetyLevel = .safe
        case 2 ... 3:
            safetyLevel = .caution
        default:
            safetyLevel = .danger
        }

        let recommendedAction = generateRecommendedAction(for: safetyLevel, issues: detectedIssues)

        return DetailedEvaluationResult(
            finalSafetyLevel: safetyLevel,
            totalScore: totalScore,
            detectedIssues: detectedIssues,
            recommendedAction: recommendedAction
        )
    }

    // MARK: - 詳細チェックメソッド

    private func checkSuspiciousCharactersDetailed(url: URL) -> DetailedEvaluationResult.EvaluationIssue? {
        let urlString = url.absoluteString

        if urlString.contains("xn--") {
            return DetailedEvaluationResult.EvaluationIssue(
                category: .punycodeDetected,
                description: "Punycodeドメイン検出",
                score: 3,
                details: "国際化ドメイン名(IDN)が使用されており、フィッシング攻撃でよく利用される手法です"
            )
        }

        let suspiciousChars = [
            "о", "а", "е", "р", "х", "с", "к", "у", "н", "т", "м", "и", "в", "б", "г", "д", "л", "з",
            "α", "β", "γ", "δ", "ε", "ζ", "η", "θ", "ι", "κ", "λ", "μ", "ν", "ξ", "ο", "π", "ρ", "σ", "τ", "υ", "φ", "χ", "ψ", "ω",
            "і", "ј", "ӏ", "о", "р", "а"
        ]

        for char in suspiciousChars where urlString.contains(char) {
            return DetailedEvaluationResult.EvaluationIssue(
                category: .suspiciousCharacters,
                description: "紛らわしい文字(同形文字攻撃)検出",
                score: 3,
                details: "視覚的に似た他言語文字が使用されており、正規サイトになりすましている可能性があります"
            )
        }

        return nil
    }

    private func checkDirectIPAccessDetailed(url: URL) -> DetailedEvaluationResult.EvaluationIssue? {
        guard let host = url.host else { return nil }

        let octet = "(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)"
        let ipv4Pattern = "^" + Array(repeating: octet, count: 4).joined(separator: "\\.") + "$"

        var isIP = false
        do {
            let ipv4Regex = try NSRegularExpression(pattern: ipv4Pattern)
            let range = NSRange(location: 0, length: host.count)
            if ipv4Regex.firstMatch(in: host, options: [], range: range) != nil {
                isIP = true
            }
        } catch {
            if host.range(of: "^[0-9.]+$", options: .regularExpression) != nil {
                isIP = true
            }
        }

        if isIP {
            return DetailedEvaluationResult.EvaluationIssue(
                category: .ipAddressAccess,
                description: "IPアドレス直接指定",
                score: 2,
                details: "正規のサービスは通常ドメイン名を使用します。IPアドレス直接アクセスは疑わしいサイトでよく見られます"
            )
        }

        if host.contains(":"), host.hasPrefix("[") || host.range(of: "^[0-9a-fA-F:]+$", options: .regularExpression) != nil {
            return DetailedEvaluationResult.EvaluationIssue(
                category: .ipAddressAccess,
                description: "IPv6アドレス直接指定",
                score: 2,
                details: "IPv6アドレスが直接指定されています。正規サービスではドメイン名が使用されることが一般的です"
            )
        }

        return nil
    }

    private func checkSubdomainDepthDetailed(url: URL) -> DetailedEvaluationResult.EvaluationIssue? {
        guard let host = url.host else { return nil }

        let parts = host.split(separator: ".")
        // 主ドメインを2ラベルとする目安で、3階層を超えるサブドメインを加点する。
        if parts.count > 5 {
            return DetailedEvaluationResult.EvaluationIssue(
                category: .deepSubdomain,
                description: "サブドメイン深い構造",
                score: 1,
                details: "\(parts.count)階層のサブドメイン構造。複雑な構造は正規サイトになりすますために使用される場合があります"
            )
        }

        return nil
    }

    private func checkPathQueryLengthDetailed(url: URL) -> DetailedEvaluationResult.EvaluationIssue? {
        let pathAndQuery = (url.path + (url.query ?? ""))
        let length = pathAndQuery.count

        if length > 200 {
            return DetailedEvaluationResult.EvaluationIssue(
                category: .longPathQuery,
                description: "異常に長いパス/クエリ",
                score: 2,
                details: "\(length)文字の長いURL。マルウェア配布や追跡、リダイレクト攻撃でよく見られる特徴です"
            )
        } else if length > 100 {
            return DetailedEvaluationResult.EvaluationIssue(
                category: .longPathQuery,
                description: "長いパス/クエリ",
                score: 1,
                details: "\(length)文字のURL。通常よりも長く、注意が必要な可能性があります"
            )
        }

        return nil
    }

    private func checkBrandSpoofingDetailed(url: URL) -> DetailedEvaluationResult.EvaluationIssue? {
        guard let host = url.host?.lowercased() else { return nil }

        // ブランド名：より厳密なマッチングのため、区切り文字を考慮
        let brandPatterns = [
            // 大手テック企業
            ("google", ["google.com", "google.co.jp", "youtube.com", "gmail.com", "googleapis.com"]),
            ("apple", ["apple.com", "icloud.com", "me.com", "mac.com"]),
            ("microsoft", ["microsoft.com", "outlook.com", "hotmail.com", "live.com", "office.com"]),
            ("amazon", ["amazon.com", "amazon.co.jp", "aws.amazon.com", "amazon.co.uk"]),
            ("facebook", ["facebook.com", "instagram.com", "whatsapp.com", "meta.com"]),
            ("meta", ["meta.com", "facebook.com", "instagram.com"]),
            ("twitter", ["twitter.com", "x.com"]),
            ("paypal", ["paypal.com"]),

            // 金融関連（より具体的な単語のみ）
            ("banking", []), // 正規ドメインなし（疑わしい）
            ("secure", []), // 正規ドメインなし（疑わしい）
            ("login", []), // 正規ドメインなし（疑わしい）
            ("account", []), // 正規ドメインなし（疑わしい）
            ("verify", []), // 正規ドメインなし（疑わしい）
            ("update", []), // 正規ドメインなし（疑わしい）

            // 日本企業
            ("rakuten", ["rakuten.co.jp"]),
            ("softbank", ["softbank.jp"]),
            ("docomo", ["docomo.ne.jp"]),
            ("yahoo", ["yahoo.co.jp"]),
            ("line", ["line.me"]),
            ("mercari", ["mercari.com"]),

            // 金融機関
            ("visa", ["visa.com"]),
            ("mastercard", ["mastercard.com"]),
            ("mufg", ["bk.mufg.jp"]),
            ("mizuho", ["mizuhobank.co.jp"]),

            // 政府系
            ("mhlw", ["mhlw.go.jp"]),
            ("cao", ["cao.go.jp"])
        ]

        // 正規ドメインのaccounts/loginサブドメインを、汎用の金融語で誤判定しない。
        let isOfficialDomain = brandPatterns.contains { _, domains in
            domains.contains { host == $0 || host.hasSuffix("." + $0) }
        }
        if isOfficialDomain {
            return nil
        }

        for (brand, legitimateDomains) in brandPatterns where isWordMatch(host: host, brand: brand) {
            let isLegitimate = legitimateDomains.contains { legitimate in
                // 完全一致 または *.legitimate（サブドメイン）の形式かチェック
                host == legitimate || host.hasSuffix("." + legitimate)
            }

            if !isLegitimate {
                return DetailedEvaluationResult.EvaluationIssue(
                    category: .brandSpoofing,
                    description: "ブランドなりすまし疑い",
                    score: 3,
                    details: "有名ブランド名「\(brand)」を含むが正規ドメインではありません。フィッシングサイトの可能性があります"
                )
            }
        }

        return nil
    }

    /**
     * 単語境界を考慮したブランド名マッチング
     * 「x」のような短い文字列の誤検出を防ぐ
     */
    private func isWordMatch(host: String, brand: String) -> Bool {
        // 短すぎる（3文字未満）ブランド名はより厳密にチェック
        if brand.count < 3 {
            // ドメイン区切り文字で囲まれているかチェック
            let separators = CharacterSet(charactersIn: ".-")
            let components = host.components(separatedBy: separators)
            return components.contains(brand)
        } else {
            // 3文字以上は通常の部分文字列マッチング
            return host.contains(brand)
        }
    }

    private func checkSuspiciousTLDDetailed(url: URL) -> DetailedEvaluationResult.EvaluationIssue? {
        guard let host = url.host?.lowercased() else { return nil }

        let executableTLDs = [".zip", ".mov", ".exe", ".scr", ".bat", ".cmd", ".pif", ".jar"]
        let freeTLDs = [".tk", ".ml", ".ga", ".cf", ".gq"]
        let otherSuspiciousTLDs = [".click", ".download", ".top", ".win", ".loan", ".work", ".party", ".date"]

        for tld in executableTLDs where host.hasSuffix(tld) {
            return DetailedEvaluationResult.EvaluationIssue(
                category: .suspiciousTLD,
                description: "実行ファイル拡張子TLD",
                score: 1,
                details: "「\(tld)」は実行ファイルの拡張子と同じで、マルウェア配布に悪用される可能性があります"
            )
        }

        for tld in freeTLDs where host.hasSuffix(tld) {
            return DetailedEvaluationResult.EvaluationIssue(
                category: .suspiciousTLD,
                description: "無料ドメインTLD",
                score: 1,
                details: "「\(tld)」は無料で取得できるTLDで、悪意あるサイトによく利用されます"
            )
        }

        for tld in otherSuspiciousTLDs where host.hasSuffix(tld) {
            return DetailedEvaluationResult.EvaluationIssue(
                category: .suspiciousTLD,
                description: "疑わしいTLD",
                score: 1,
                details: "「\(tld)」は疑わしい活動に使用されることが多いTLDです"
            )
        }

        return nil
    }

    private func generateRecommendedAction(for safetyLevel: SafetyLevel, issues: [DetailedEvaluationResult.EvaluationIssue]) -> String {
        switch safetyLevel {
        case .safe:
            return "安全と判定されました。問題ありません"
        case .caution:
            var actions = ["注意深く検討してからアクセスしてください"]
            if issues.contains(where: { $0.category == .brandSpoofing }) {
                actions.append("URLが期待していたサイトと一致するかよく確認してください")
            }
            if issues.contains(where: { $0.category == .punycodeDetected || $0.category == .suspiciousCharacters }) {
                actions.append("ドメイン名の文字に注意してください")
            }
            return actions.joined(separator: "。")
        case .danger:
            var actions = ["このURLにはアクセスしないことを強く推奨します"]
            if issues.contains(where: { $0.category == .brandSpoofing }) {
                actions.append("フィッシングサイトの可能性が高いです")
            }
            if issues.contains(where: { $0.category == .punycodeDetected || $0.category == .suspiciousCharacters }) {
                actions.append("なりすましサイトの可能性があります")
            }
            actions.append("疑わしいメールやメッセージからのリンクではありませんか？")
            return actions.joined(separator: "。")
        }
    }

    // MARK: - 便利メソッド

    /**
     * 簡易評価メソッド（SafetyLevelのみ取得）
     * @param url: 評価対象URL
     * @return: 安全性レベル
     */
    func evaluate(url: String) -> SafetyLevel {
        return evaluateWithDetails(url: url).finalSafetyLevel
    }
}
