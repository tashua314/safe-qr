import Foundation
@testable import SafeQR
import UIKit
import XCTest

final class GoogleWarningPresentationTests: XCTestCase {
    @MainActor
    func testLocalWarningHasNoGoogleAttribution() {
        let controller = OpenConfirmViewController(url: "https://local.invalid/", safetyLevel: .caution)
        controller.loadViewIfNeeded()
        XCTAssertTrue(advisories(in: controller.view).isEmpty)
    }

    @MainActor
    func testGoogleThreatWarningHasAttributionAndContext() throws {
        let controller = OpenConfirmViewController(
            url: "https://private.invalid/secret?token=private", safetyLevel: .danger,
            googleThreats: [.malware, .unwantedSoftware, .socialEngineering]
        )
        controller.loadViewIfNeeded()
        let advisory = try XCTUnwrap(advisories(in: controller.view).first)
        XCTAssertTrue(advisory.text.contains("Advisory provided by Google"))
        XCTAssertTrue(advisory.text.contains("誤判定や見逃し"))
        XCTAssertTrue(advisory.text.contains("フィッシング等の説明"))
        XCTAssertTrue(advisory.text.contains("マルウェア等の説明"))
        let links = linkTargets(advisory)
        XCTAssertEqual(links.count, 3, "同じ定義リンクを重複させない")
        XCTAssertTrue(links.allSatisfy { $0.host == "developers.google.com" && $0.query == nil && $0.fragment == nil })
        XCTAssertFalse(links.contains { $0.absoluteString.contains("private") })
    }

    @MainActor
    func testIntroductionExplainsLimitationsWithoutInventingAThreat() {
        let view = GoogleSafetyAdvisoryView()
        view.configureIntroduction()
        XCTAssertTrue(view.text.contains("精度・信頼性は保証されません"))
        XCTAssertTrue(view.text.contains("誤判定や見逃し"))
        XCTAssertEqual(linkTargets(view).map(\.absoluteString), ["https://developers.google.com/safe-browsing/v4/advisory"])
        XCTAssertFalse(view.text.contains("フィッシング等の説明"))
    }

    @MainActor
    func testUnknownInformationDoesNotClaimGoogleRiskAttribution() {
        let controller = OpenConfirmViewController(
            url: "https://example.invalid/", safetyLevel: .safe, isExternalCheckUnverified: true
        )
        controller.loadViewIfNeeded()
        XCTAssertTrue(advisories(in: controller.view).isEmpty)
    }

    @MainActor
    private func advisories(in view: UIView) -> [GoogleSafetyAdvisoryView] {
        view.subviews.flatMap { child in
            (child as? GoogleSafetyAdvisoryView).map { [$0] } ?? advisories(in: child)
        }
    }

    @MainActor
    private func linkTargets(_ view: UITextView) -> [URL] {
        var links: [URL] = []
        view.attributedText.enumerateAttribute(.link, in: NSRange(location: 0, length: view.attributedText.length)) { value, _, _ in
            if let url = value as? URL {
                links.append(url)
            } else if let value = value as? String, let url = URL(string: value) {
                links.append(url)
            }
        }
        return links
    }
}
