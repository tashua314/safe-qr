@testable import SafeQR
import XCTest

final class UrlRiskEvaluatorTests: XCTestCase {
    private let evaluator = UrlRiskEvaluator()
    private let settingsStore = SettingsStore.shared
    private var originalStrictness = SafetyStrictness.standard

    override func setUp() {
        super.setUp()
        originalStrictness = settingsStore.safetyStrictness
        settingsStore.safetyStrictness = .standard
    }

    override func tearDown() {
        settingsStore.safetyStrictness = originalStrictness
        super.tearDown()
    }

    func testSafeURLs() {
        for url in [
            "https://www.google.com", "https://apple.com", "https://github.com/user/repo",
            "https://stackoverflow.com/questions/123", "https://www.wikipedia.org"
        ] {
            XCTAssertEqual(evaluator.evaluate(url: url), .safe, url)
        }
    }

    func testSimpleURLs() {
        for url in ["https://example.com", "https://test.jp", "http://localhost:3000"] {
            XCTAssertEqual(evaluator.evaluate(url: url), .safe, url)
        }
    }

    func testCautionLevelURLs() {
        // 深いサブドメイン1点と100文字超のパス1点を組み合わせる。
        let url = "https://sub1.sub2.sub3.sub4.example.com/" + String(repeating: "a", count: 101)
        let result = evaluator.evaluateWithDetails(url: url)
        XCTAssertEqual(result.totalScore, 2)
        XCTAssertEqual(result.finalSafetyLevel, .caution)
    }

    func testLongPathQueryURLs() {
        let url = "https://example.com/search?" + String(repeating: "param=value&", count: 20)
        let result = evaluator.evaluateWithDetails(url: url)
        XCTAssertEqual(result.totalScore, 2)
        XCTAssertEqual(result.finalSafetyLevel, .caution)
    }

    func testIPAddressURLs() {
        for url in [
            "https://192.168.1.1/malware", "http://10.0.0.1/phishing",
            "https://172.16.0.100:8080/suspicious", "https://[2001:db8::1]/"
        ] {
            let result = evaluator.evaluateWithDetails(url: url)
            XCTAssertEqual(result.totalScore, 2, url)
            XCTAssertEqual(result.finalSafetyLevel, .caution, url)
        }
    }

    func testBrandSpoofingURLs() {
        for url in [
            "https://google-security.malicious.com/signin", "https://apple-support.phishing.net/account",
            "https://paypal-verify.suspicious.org/login", "https://amazon-update.fake.com/payment"
        ] {
            let result = evaluator.evaluateWithDetails(url: url)
            XCTAssertEqual(result.totalScore, 3, url)
            XCTAssertEqual(result.finalSafetyLevel, .caution, url)
            XCTAssertTrue(result.detectedIssues.contains { $0.category == .brandSpoofing }, url)
        }
    }

    func testSuspiciousTLDs() {
        for url in ["https://malware.zip", "https://phishing.mov", "https://suspicious.tk"] {
            let result = evaluator.evaluateWithDetails(url: url)
            XCTAssertEqual(result.totalScore, 1, url)
            XCTAssertEqual(result.finalSafetyLevel, .safe, url)
            XCTAssertTrue(result.detectedIssues.contains { $0.category == .suspiciousTLD }, url)
        }
    }

    func testPunycodeURLs() {
        for url in ["https://xn--google-123.com", "https://xn--apple-456.net"] {
            XCTAssertEqual(evaluator.evaluate(url: url), .danger, url)
        }
    }

    func testInvalidURLs() {
        for strictness in SafetyStrictness.allCases {
            settingsStore.safetyStrictness = strictness
            for url in [
                "invalid-url", "", "/relative/path", "//example.com/path", "https://", "https:///path",
                "ftp://not-http-url.com", "javascript:alert('xss')", "file:///tmp/test"
            ] {
                XCTAssertEqual(evaluator.evaluate(url: url), .danger, "\(strictness): \(url)")
            }
        }
    }

    func testHighStrictnessIncreasesDangerLevel() {
        settingsStore.safetyStrictness = .high
        XCTAssertEqual(evaluator.evaluate(url: "https://google-security.example.com"), .danger)
    }

    func testLowStrictnessDecreasesDangerLevel() {
        settingsStore.safetyStrictness = .low
        XCTAssertEqual(evaluator.evaluate(url: "https://192.168.1.1"), .safe)
    }

    func testMultipleDangerFactors() {
        let url = "https://192.168.1.1/path?" + String(repeating: "param=value&", count: 30)
        let result = evaluator.evaluateWithDetails(url: url)
        XCTAssertEqual(result.totalScore, 4)
        XCTAssertEqual(result.finalSafetyLevel, .danger)
    }

    func testLegitimateDomainsNotFlaggedAsSpoofing() {
        for url in [
            "https://accounts.google.com/signin", "https://appleid.apple.com/account",
            "https://www.paypal.com/signin"
        ] {
            XCTAssertFalse(evaluator.evaluateWithDetails(url: url).detectedIssues.contains { $0.category == .brandSpoofing }, url)
        }
    }

    func testSpecialCharactersInURL() {
        for url in [
            "https://example.com/path with spaces", "https://example.com/パス",
            "https://example.com/search?q=特殊文字"
        ] {
            XCTAssertEqual(evaluator.evaluateWithDetails(url: url).finalSafetyLevel, .safe, url)
        }
    }

    func testVeryLongURL() {
        let url = "https://example.com/" + String(repeating: "verylongpath/", count: 150)
        let result = evaluator.evaluateWithDetails(url: url)
        XCTAssertEqual(result.totalScore, 2)
        XCTAssertEqual(result.finalSafetyLevel, .caution)
    }

    func testScoreBoundariesAtEveryStrictness() {
        let fixtures: [(String, Int)] = [
            ("https://example.com", 0), ("https://example.zip", 1),
            ("https://192.168.1.1", 2), ("https://google-security.example.com", 3),
            ("https://192.168.1.1/" + String(repeating: "a", count: 201), 4)
        ]
        for strictness in SafetyStrictness.allCases {
            settingsStore.safetyStrictness = strictness
            for (url, baseScore) in fixtures {
                let score = max(0, baseScore + strictness.scoreModifier)
                let level: SafetyLevel = score <= 1 ? .safe : score <= 3 ? .caution : .danger
                let result = evaluator.evaluateWithDetails(url: url)
                XCTAssertEqual(result.totalScore, score, "\(strictness): \(url)")
                XCTAssertEqual(result.finalSafetyLevel, level, "\(strictness): \(url)")
            }
        }
    }

    func testSubdomainDepthBoundary() {
        XCTAssertEqual(evaluator.evaluateWithDetails(url: "https://a.b.c.example.com").totalScore, 0)
        XCTAssertEqual(evaluator.evaluateWithDetails(url: "https://a.b.c.d.example.com").totalScore, 1)
    }

    func testPathLengthBoundaries() {
        for (length, score) in [(100, 0), (101, 1), (200, 1), (201, 2)] {
            // URL.pathには先頭のスラッシュも含まれる。
            let url = "https://example.com/" + String(repeating: "a", count: length - 1)
            XCTAssertEqual(evaluator.evaluateWithDetails(url: url).totalScore, score)
        }
    }

    func testUppercaseHTTPSScheme() {
        XCTAssertEqual(evaluator.evaluate(url: "HTTPS://example.com/path"), .safe)
    }

    func testOfficialDomainSuffixBoundary() {
        for url in ["https://google.com.evil.test", "https://evilgoogle.com", "https://apple.com.evil.test"] {
            XCTAssertTrue(evaluator.evaluateWithDetails(url: url).detectedIssues.contains { $0.category == .brandSpoofing }, url)
        }
    }
}
