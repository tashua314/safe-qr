# ドメインI/F（抜粋）

```swift
// 危険度
public enum SafetyLevel: Int { case safe = 0, caution = 1, danger = 2 }

// 厳しさ
public enum Strictness { case low, standard, high }

// 評価器
public protocol UrlRiskEvaluating {
    func evaluate(url: URL, strictness: Strictness, reputation: ReputationChecking?) -> SafetyLevel
}

// レピュテーション
public protocol ReputationChecking {
    /// 引数はドメインハッシュ等（URL生値は渡さない）
    func check(domainHash: String) -> SafetyLevel? // nil=不明
}

// 履歴
public struct ScanRecord {
    public let id: UUID
    public let url: URL
    public var title: String?
    public var safety: SafetyLevel
    public var scannedAt: Date
    public var visitCount: Int
}

public protocol HistoryRepository {
    func upsert(_ record: ScanRecord) throws // 既存URLならvisitCount+1, scannedAt更新
    func recent(limit: Int) throws -> [ScanRecord]
    func delete(id: UUID) throws
    func deleteAll() throws
    var maxRecords: Int { get } // 50 固定
}
// スキャナ
public protocol QRScannerService {
    var onDetectURL: ((URL) -> Void)? { get set }
    func startSession() throws
    func stopSession()
}
```
