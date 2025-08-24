import Foundation
import CommonCrypto

class UrlRiskEvaluator {
    private let settingsStore = SettingsStore.shared
    
    func evaluate(url: String) -> SafetyLevel {
        guard let url = URL(string: url) else {
            return .danger
        }
        
        var score = 0
        
        // Punycode/紛らわしい文字混在チェック
        score += checkSuspiciousCharacters(url: url)
        
        // IP直打ちチェック
        score += checkDirectIPAccess(url: url)
        
        // サブドメイン深さチェック
        score += checkSubdomainDepth(url: url)
        
        // パス/クエリ長チェック
        score += checkPathQueryLength(url: url)
        
        // ブランド語チェック
        score += checkBrandSpoofing(url: url)
        
        // 疑義TLDチェック
        score += checkSuspiciousTLD(url: url)
        
        // 厳しさ設定による調整
        score = max(0, score + settingsStore.safetyStrictness.scoreModifier)
        
        // SafetyLevelに変換
        switch score {
        case 0...1:
            return .safe
        case 2...3:
            return .caution
        default:
            return .danger
        }
    }
    
    private func checkSuspiciousCharacters(url: URL) -> Int {
        let urlString = url.absoluteString
        
        // Punycode検出
        if urlString.contains("xn--") {
            return 3
        }
        
        // 紛らわしい文字の検出（同形文字攻撃対策）
        let suspiciousChars = [
            // キリル文字（ロシア語）
            "о", "а", "е", "р", "х", "с", "к", "у", "н", "т", "м", "и", "в", "б", "г", "д", "л", "з",
            // ギリシャ文字
            "α", "β", "γ", "δ", "ε", "ζ", "η", "θ", "ι", "κ", "λ", "μ", "ν", "ξ", "ο", "π", "ρ", "σ", "τ", "υ", "φ", "χ", "ψ", "ω",
            // その他の同形文字
            "і", "ј", "ӏ", "о", "р", "а" // 区別が困難な文字
        ]
        
        for char in suspiciousChars {
            if urlString.contains(char) {
                return 3
            }
        }
        
        return 0
    }
    
    private func checkDirectIPAccess(url: URL) -> Int {
        guard let host = url.host else { return 0 }
        
        // IPv4パターンの厳密チェック（0-255の範囲制限付き）
        let ipv4Pattern = "^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
        
        do {
            let ipv4Regex = try NSRegularExpression(pattern: ipv4Pattern)
            let range = NSRange(location: 0, length: host.count)
            if ipv4Regex.firstMatch(in: host, options: [], range: range) != nil {
                return 2
            }
        } catch {
            // 正規表現エラーの場合は、簡易チェックにフォールバック
            if host.range(of: "^[0-9.]+$", options: .regularExpression) != nil {
                return 2
            }
        }
        
        // IPv6パターンチェック（簡易）
        if host.contains(":") && (host.hasPrefix("[") || host.range(of: "^[0-9a-fA-F:]+$", options: .regularExpression) != nil) {
            return 2
        }
        
        return 0
    }
    
    private func checkSubdomainDepth(url: URL) -> Int {
        guard let host = url.host else { return 0 }
        
        let parts = host.split(separator: ".")
        if parts.count > 4 { // www.sub.example.com = 4 parts
            return 1
        }
        
        return 0
    }
    
    private func checkPathQueryLength(url: URL) -> Int {
        let pathAndQuery = (url.path + (url.query ?? ""))
        
        if pathAndQuery.count > 200 {
            return 2
        } else if pathAndQuery.count > 100 {
            return 1
        }
        
        return 0
    }
    
    private func checkBrandSpoofing(url: URL) -> Int {
        guard let host = url.host?.lowercased() else { return 0 }
        
        let brands = [
            // グローバル大手
            "google", "apple", "microsoft", "amazon", "facebook", "meta", "twitter", "x", "paypal", 
            "bank", "banking", "secure", "login", "account", "auth", "verify", "update",
            // 日本の主要ブランド
            "rakuten", "softbank", "docomo", "au", "yahoo", "line", "mercari", "zozotown",
            // 金融系
            "visa", "mastercard", "amex", "jcb", "mufg", "mizuho", "sumitomo", "resona",
            // 政府・公的機関
            "gov", "go.jp", "mhlw", "cao", "nta", "jma"
        ]
        let legitimateDomains = [
            // Google系
            "google.com", "google.co.jp", "youtube.com", "gmail.com", "googleapis.com",
            // Apple系
            "apple.com", "icloud.com", "me.com", "mac.com",
            // Microsoft系
            "microsoft.com", "outlook.com", "hotmail.com", "live.com", "office.com",
            // Amazon系
            "amazon.com", "amazon.co.jp", "aws.amazon.com", "amazon.co.uk",
            // Meta/Facebook系
            "facebook.com", "instagram.com", "whatsapp.com", "meta.com",
            // その他グローバル
            "twitter.com", "x.com", "paypal.com", "linkedin.com", "github.com",
            // 日本系
            "rakuten.co.jp", "softbank.jp", "docomo.ne.jp", "au.com", "yahoo.co.jp", 
            "line.me", "mercari.com", "zozo.jp", "zozotown.com",
            // 金融系
            "visa.com", "mastercard.com", "americanexpress.com", "jcb.co.jp",
            "bk.mufg.jp", "mizuhobank.co.jp", "smbc.co.jp", "resonabank.co.jp",
            // 政府系
            "cao.go.jp", "mhlw.go.jp", "nta.go.jp", "jma.go.jp"
        ]
        
        for brand in brands {
            if host.contains(brand) {
                // 正規ドメインかチェック
                let isLegitimate = legitimateDomains.contains { legitimate in
                    host.hasSuffix(legitimate)
                }
                
                if !isLegitimate {
                    return 3
                }
            }
        }
        
        return 0
    }
    
    private func checkSuspiciousTLD(url: URL) -> Int {
        guard let host = url.host?.lowercased() else { return 0 }
        
        let suspiciousTLDs = [
            // 実行ファイル拡張子（危険度高）
            ".zip", ".mov", ".exe", ".scr", ".bat", ".cmd", ".com", ".pif", ".jar",
            // 無料ドメイン系（悪用されやすい）
            ".tk", ".ml", ".ga", ".cf", ".gq", 
            // その他の注意すべきTLD
            ".click", ".download", ".top", ".win", ".loan", ".work", ".party", ".date"
        ]
        
        for tld in suspiciousTLDs {
            if host.hasSuffix(tld) {
                return 1
            }
        }
        
        return 0
    }
}