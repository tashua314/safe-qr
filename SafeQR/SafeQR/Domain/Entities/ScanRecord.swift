import Foundation

/**
 * スキャン履歴のドメインエンティティ
 * Core DataのScanRecordEntityとは分離して、ドメイン層で扱うモデル
 */
struct ScanRecord {
    // MARK: - プロパティ

    /// 一意識別子
    let id: UUID

    /// スキャンしたURL
    let url: String

    /// ページタイトル（後から取得するため Optional）
    var title: String?

    /// ドメインのハッシュ値（プライバシー保護のため、URL生値は保存しない）
    let domainHash: String

    /// 安全性レベル（0: safe, 1: caution, 2: danger）
    let safety: SafetyLevel

    /// 最初にスキャンした日時
    let scannedAt: Date

    /// 訪問回数（同じURLを複数回スキャンした場合にインクリメント）
    var visitCount: Int32

    /// ファビコンデータ（オプショナル）
    var favicon: Data?

    // MARK: - イニシャライザ

    /**
     * 新規スキャンレコード作成用イニシャライザ
     * @param url: スキャンしたURL
     * @param safety: 危険度評価結果
     * @param domainHash: ドメインのハッシュ値
     */
    init(url: String, safety: SafetyLevel, domainHash: String) {
        id = UUID()
        self.url = url
        title = nil // 後から取得
        self.domainHash = domainHash
        self.safety = safety
        scannedAt = Date()
        visitCount = 1
        favicon = nil
    }

    /**
     * 既存データからの復元用イニシャライザ
     * Core DataのScanRecordEntityから変換時に使用
     */
    init(
        id: UUID,
        url: String,
        title: String?,
        domainHash: String,
        safety: SafetyLevel,
        scannedAt: Date,
        visitCount: Int32,
        favicon: Data?
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.domainHash = domainHash
        self.safety = safety
        self.scannedAt = scannedAt
        self.visitCount = visitCount
        self.favicon = favicon
    }

    // MARK: - ヘルパーメソッド

    /**
     * URLからドメイン部分を抽出
     * @param url: 対象URL
     * @return: ドメイン文字列（取得失敗時はURL全体）
     */
    static func extractDomain(from url: String) -> String {
        guard let urlObject = URL(string: url),
              let host = urlObject.host else {
            return url // ドメイン抽出失敗時はURL全体を返す
        }
        return host
    }

    /**
     * ドメインからハッシュ値を生成
     * プライバシー保護のため、ドメインのみをハッシュ化して保存
     * @param url: 対象URL
     * @return: SHA256ハッシュ値の16進文字列
     */
    static func generateDomainHash(from url: String) -> String {
        let domain = extractDomain(from: url)

        // SHA256ハッシュ生成（簡易版）
        // 実際の実装ではより適切なハッシュライブラリを使用
        return String(domain.hashValue)
    }

    /**
     * 表示用のタイトルを取得
     * title が nil の場合はドメイン名を返す
     */
    var displayTitle: String {
        return title ?? ScanRecord.extractDomain(from: url)
    }

    /**
     * 安全性レベルの表示用テキスト
     */
    var safetyDisplayText: String {
        return safety.displayName
    }
}
