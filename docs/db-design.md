# Core Data スキーマ

- **ScanRecordEntity**
  - `id: UUID` (primary)
  - `url: String` (indexed, unique-ish)
  - `title: String?`
  - `domainHash: String` (indexed)
  - `safety: Int16`（0/1/2）
  - `scannedAt: Date`（index DESC）
  - `visitCount: Int32`
  - `favicon: Binary?`（任意）

## ポリシー
- **最大50件**：保存時に件数>50なら `scannedAt` 昇順で古いものを削除
- 同一URL検出時は `visitCount += 1` と `scannedAt` 更新
