import Foundation

/// 未設定・未展開のビルド変数・配布テンプレートを認証済みの設定として送信しない。
enum SafeBrowsingAPIKey {
    static func fromBundle(_ bundle: Bundle = .main) -> String? {
        validated(bundle.object(forInfoDictionaryKey: "SafeBrowsingAPIKey") as? String)
    }

    static func validated(_ rawValue: String?) -> String? {
        guard let value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty,
              !value.uppercased().hasPrefix("YOUR_"),
              value
              .rangeOfCharacter(from: CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
                  .inverted) == nil
        else { return nil }
        return value
    }
}
