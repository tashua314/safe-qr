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
        
        // 紛らわしい文字の検出（例：同形文字）
        let suspiciousChars = ["о", "а", "е", "р", "х", "с", "к"] // キリル文字の例
        for char in suspiciousChars {
            if urlString.contains(char) {
                return 3
            }
        }
        
        return 0
    }
    
    private func checkDirectIPAccess(url: URL) -> Int {
        guard let host = url.host else { return 0 }
        
        // IPv4パターンの簡易チェック
        let ipv4Pattern = "^([0-9]{1,3}\\.){3}[0-9]{1,3}$"
        let ipv4Regex = try? NSRegularExpression(pattern: ipv4Pattern)
        let range = NSRange(location: 0, length: host.count)
        
        if ipv4Regex?.firstMatch(in: host, options: [], range: range) != nil {
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
        
        let brands = ["google", "apple", "microsoft", "amazon", "facebook", "twitter", "paypal", "bank"]
        let legitimateDomains = [
            "google.com", "google.co.jp",
            "apple.com",
            "microsoft.com",
            "amazon.com", "amazon.co.jp",
            "facebook.com",
            "twitter.com",
            "paypal.com",
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
        
        let suspiciousTLDs = [".zip", ".mov", ".exe", ".scr", ".tk", ".ml", ".ga", ".cf"]
        
        for tld in suspiciousTLDs {
            if host.hasSuffix(tld) {
                return 1
            }
        }
        
        return 0
    }
}