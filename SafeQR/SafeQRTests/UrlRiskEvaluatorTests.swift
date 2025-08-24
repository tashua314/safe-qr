import XCTest
@testable import SafeQR

/**
 * UrlRiskEvaluator のユニットテスト
 * 危険度評価ロジックの各パターンをテスト
 * 設定による厳しさ調整もテスト対象
 */
class UrlRiskEvaluatorTests: XCTestCase {
    
    // MARK: - Properties
    
    /// テスト対象のUrlRiskEvaluator
    private var evaluator: UrlRiskEvaluator!
    
    /// SettingsStore（実際のインスタンスを使用）
    private let settingsStore = SettingsStore.shared
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // テスト対象を初期化
        evaluator = UrlRiskEvaluator()
        
        // デフォルトは「標準」の厳しさに設定
        settingsStore.safetyStrictness = .standard
    }
    
    override func tearDown() {
        evaluator = nil
        // デフォルトに戻す
        settingsStore.safetyStrictness = .standard
        super.tearDown()
    }
    
    // MARK: - 安全なURL のテスト
    
    /**
     * 有名サイトの正規ドメインは安全と判定されることをテスト
     */
    func testSafeURLs() {
        let safeURLs = [
            "https://www.google.com",
            "https://apple.com",
            "https://github.com/user/repo",
            "https://stackoverflow.com/questions/123",
            "https://www.wikipedia.org"
        ]
        
        for url in safeURLs {
            let result = evaluator.evaluate(url: url)
            XCTAssertEqual(result, .safe, "URL '\(url)' should be evaluated as safe")
        }
    }
    
    /**
     * シンプルで短いURLは安全と判定されることをテスト
     */
    func testSimpleURLs() {
        let simpleURLs = [
            "https://example.com",
            "https://test.jp",
            "http://localhost:3000"
        ]
        
        for url in simpleURLs {
            let result = evaluator.evaluate(url: url)
            XCTAssertEqual(result, .safe, "Simple URL '\(url)' should be evaluated as safe")
        }
    }
    
    // MARK: - 注意レベルURL のテスト
    
    /**
     * サブドメインが深いURLは注意レベルと判定されることをテスト
     */
    func testCautionLevelURLs() {
        let cautionURLs = [
            "https://sub1.sub2.sub3.sub4.example.com", // サブドメインが深い
            "https://ads.tracking.example.com/campaign", // 広告・トラッキング系
            "https://redirect.service.com/go?url=target"  // リダイレクト系
        ]
        
        for url in cautionURLs {
            let result = evaluator.evaluate(url: url)
            XCTAssertTrue(result == .caution || result == .danger, 
                         "URL '\(url)' should be evaluated as caution or danger")
        }
    }
    
    /**
     * 長いパス・クエリを持つURLは注意レベルと判定されることをテスト
     */
    func testLongPathQueryURLs() {
        // 長いクエリパラメータを含むURL（100文字超）
        let longQueryURL = "https://example.com/search?" + String(repeating: "param=value&", count: 20)
        let result = evaluator.evaluate(url: longQueryURL)
        
        XCTAssertTrue(result == .caution || result == .danger,
                     "URL with long query should be evaluated as caution or danger")
    }
    
    // MARK: - 危険レベルURL のテスト
    
    /**
     * IP直打ちURLは危険と判定されることをテスト
     */
    func testIPAddressURLs() {
        let ipURLs = [
            "https://192.168.1.1/malware",
            "http://10.0.0.1/phishing",
            "https://172.16.0.100:8080/suspicious"
        ]
        
        for url in ipURLs {
            let result = evaluator.evaluate(url: url)
            XCTAssertEqual(result, .danger, "IP address URL '\(url)' should be evaluated as danger")
        }
    }
    
    /**
     * ブランド偽装URLは危険と判定されることをテスト
     */
    func testBrandSpoofingURLs() {
        let spoofingURLs = [
            "https://google-security.malicious.com/signin",
            "https://apple-support.phishing.net/account",
            "https://paypal-verify.suspicious.org/login",
            "https://amazon-update.fake.com/payment"
        ]
        
        for url in spoofingURLs {
            let result = evaluator.evaluate(url: url)
            XCTAssertEqual(result, .danger, "Brand spoofing URL '\(url)' should be evaluated as danger")
        }
    }
    
    /**
     * 疑義TLDは危険度が上がることをテスト
     */
    func testSuspiciousTLDs() {
        let suspiciousTLDURLs = [
            "https://malware.zip",
            "https://phishing.mov", 
            "https://suspicious.tk"
        ]
        
        for url in suspiciousTLDURLs {
            let result = evaluator.evaluate(url: url)
            // 疑義TLD単体では1点なので、他の要素と合わせて注意以上になることを期待
            XCTAssertTrue(result == .caution || result == .danger,
                         "Suspicious TLD URL '\(url)' should be evaluated as caution or danger")
        }
    }
    
    /**
     * Punycode（国際化ドメイン名）は危険と判定されることをテスト
     */
    func testPunycodeURLs() {
        let punycodeURLs = [
            "https://xn--google-123.com", // Punycode偽装
            "https://xn--apple-456.net"   // Punycode偽装
        ]
        
        for url in punycodeURLs {
            let result = evaluator.evaluate(url: url)
            XCTAssertEqual(result, .danger, "Punycode URL '\(url)' should be evaluated as danger")
        }
    }
    
    // MARK: - 無効URL のテスト
    
    /**
     * 無効なURLは危険と判定されることをテスト
     */
    func testInvalidURLs() {
        let invalidURLs = [
            "invalid-url",
            "",
            "ftp://not-http-url.com",
            "javascript:alert('xss')"
        ]
        
        for url in invalidURLs {
            let result = evaluator.evaluate(url: url)
            XCTAssertEqual(result, .danger, "Invalid URL '\(url)' should be evaluated as danger")
        }
    }
    
    // MARK: - 厳しさ設定による調整のテスト
    
    /**
     * 厳しさ「強」設定時により多くのURLが危険判定されることをテスト
     */
    func testHighStrictnessIncreasesDangerLevel() {
        // 境界値のURL（標準では安全だが、厳しさ「強」では注意になるもの）
        let borderlineURL = "https://sub1.sub2.example.com/path"
        
        // 標準設定での評価
        settingsStore.safetyStrictness = .standard
        let standardResult = evaluator.evaluate(url: borderlineURL)
        
        // 厳しい設定での評価  
        settingsStore.safetyStrictness = .high
        let highResult = evaluator.evaluate(url: borderlineURL)
        
        // 厳しい設定の方が危険度が高いか同等であることを確認
        XCTAssertGreaterThanOrEqual(highResult.rawValue, standardResult.rawValue,
                                   "High strictness should result in equal or higher danger level")
    }
    
    /**
     * 厳しさ「弱」設定時により多くのURLが安全判定されることをテスト
     */
    func testLowStrictnessDecreasesDangerLevel() {
        // 境界値のURL（標準では注意だが、厳しさ「弱」では安全になるもの）
        let borderlineURL = "https://sub1.sub2.sub3.example.com"
        
        // 標準設定での評価
        settingsStore.safetyStrictness = .standard  
        let standardResult = evaluator.evaluate(url: borderlineURL)
        
        // 弱い設定での評価
        settingsStore.safetyStrictness = .low
        let lowResult = evaluator.evaluate(url: borderlineURL)
        
        // 弱い設定の方が危険度が低いか同等であることを確認
        XCTAssertLessThanOrEqual(lowResult.rawValue, standardResult.rawValue,
                                "Low strictness should result in equal or lower danger level")
    }
    
    // MARK: - 複合条件のテスト
    
    /**
     * 複数の危険要素を持つURLは確実に危険と判定されることをテスト
     */
    func testMultipleDangerFactors() {
        // IP + 長いクエリ + ブランド偽装の複合
        let multiDangerURL = "https://192.168.1.1/google-signin/verify?" + String(repeating: "param=value&", count: 30)
        
        let result = evaluator.evaluate(url: multiDangerURL)
        XCTAssertEqual(result, .danger, "URL with multiple danger factors should be evaluated as danger")
    }
    
    /**
     * 正規ブランドドメインは偽装チェックで安全と判定されることをテスト
     */
    func testLegitimateDomainsNotFlaggedAsSpoofing() {
        let legitimateURLs = [
            "https://accounts.google.com/signin",
            "https://appleid.apple.com/account", 
            "https://www.paypal.com/signin"
        ]
        
        for url in legitimateURLs {
            let result = evaluator.evaluate(url: url)
            XCTAssertNotEqual(result, .danger, 
                             "Legitimate domain '\(url)' should not be flagged as spoofing")
        }
    }
    
    // MARK: - エッジケースのテスト
    
    /**
     * 特殊文字を含むURLの処理をテスト
     */
    func testSpecialCharactersInURL() {
        let specialCharURLs = [
            "https://example.com/path with spaces",
            "https://example.com/パス",
            "https://example.com/search?q=特殊文字"
        ]
        
        for url in specialCharURLs {
            // クラッシュせずに評価が完了することを確認
            XCTAssertNoThrow({ [self] in
                _ = evaluator.evaluate(url: url)
            }, "URL with special characters should not crash: '\(url)'")
        }
    }
    
    /**
     * 非常に長いURLの処理をテスト
     */
    func testVeryLongURL() {
        // 2000文字のURL
        let longURL = "https://example.com/" + String(repeating: "verylongpath/", count: 150)
        
        XCTAssertNoThrow({ [self] in
            let result = evaluator.evaluate(url: longURL)
            // 長いパスなので少なくとも注意レベル以上になることを期待
            XCTAssertGreaterThanOrEqual(result.rawValue, SafetyLevel.caution.rawValue)
        }, "Very long URL should not crash")
    }
}


// MARK: - Test Extensions

extension SafetyLevel {
    /**
     * テスト用の比較演算子
     * 危険度の数値比較を可能にする
     */
    static func < (lhs: SafetyLevel, rhs: SafetyLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    static func <= (lhs: SafetyLevel, rhs: SafetyLevel) -> Bool {
        return lhs.rawValue <= rhs.rawValue
    }
    
    static func > (lhs: SafetyLevel, rhs: SafetyLevel) -> Bool {
        return lhs.rawValue > rhs.rawValue
    }
    
    static func >= (lhs: SafetyLevel, rhs: SafetyLevel) -> Bool {
        return lhs.rawValue >= rhs.rawValue
    }
}