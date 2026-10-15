import UIKit

/// Googleが検出した脅威の警告だけに出典を付ける。リンクへスキャンURLは含めない。
final class GoogleSafetyAdvisoryView: UITextView {
    private static let reliabilityNotice = "Googleの情報の精度・信頼性は保証されません。誤判定や見逃しがあり、安全性を保証するものではありません。"

    func configureIntroduction() {
        configureText(threats: [], introduction: true)
        accessibilityIdentifier = "外部チェックの説明"
    }

    func configure(threats: [SafeBrowsingAPIClient.ThreatType]) {
        configureText(threats: threats, introduction: false)
    }

    private func configureText(threats: [SafeBrowsingAPIClient.ThreatType], introduction: Bool) {
        attributedText = nil
        guard introduction || !threats.isEmpty else { return }
        isEditable = false
        isScrollEnabled = false
        backgroundColor = .clear
        textContainerInset = .zero
        translatesAutoresizingMaskIntoConstraints = false
        let text = NSMutableAttributedString(
            string: "Advisory provided by Google",
            attributes: [.link: "https://developers.google.com/safe-browsing/v4/advisory"]
        )
        text.append(NSAttributedString(string: "\n" + Self.reliabilityNotice))
        var included = Set<String>()
        for threat in SafeBrowsingAPIClient.ThreatType.allCases where threats.contains(threat) {
            let link: String
            let label: String
            switch threat {
            case .socialEngineering:
                label = "フィッシング等の説明"
                link = "https://developers.google.com/search/docs/monitor-debug/security/social-engineering"
            case .malware, .unwantedSoftware:
                label = "マルウェア等の説明"
                link = "https://developers.google.com/search/docs/monitor-debug/security/malware"
            case .potentiallyHarmfulApplication:
                label = "有害なアプリの説明"
                link = "https://developers.google.com/android/play-protect/potentially-harmful-applications"
            }
            guard included.insert(link).inserted else { continue }
            text.append(NSAttributedString(string: "\n"))
            text.append(NSAttributedString(string: label, attributes: [.link: link]))
        }
        text.addAttribute(.font, value: UIFont.preferredFont(forTextStyle: .footnote), range: NSRange(location: 0, length: text.length))
        text.addAttribute(.foregroundColor, value: UIColor.label, range: NSRange(location: 0, length: text.length))
        attributedText = text
    }
}
