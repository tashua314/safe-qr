# 現在の内部インターフェース

2026-10-15時点。外部向け公開APIではなく、アプリ内部のSwift型と責務を示す。型定義の正本はソースに置く。

| 責務 | 実装・契約 | 主な動作 |
|---|---|---|
| カメラ | `QRScannerServiceProtocol` / `QRScannerService` | `scanResult: AnyPublisher<String, Never>`、権限要求、開始/停止、トーチ、プレビュー。SimulatorはDebugのテスト用URLボタンを使う |
| QR内容の検証 | `QRCodeProcessorProtocol` / `QRCodeProcessor` | URL形式とスキームを検証し、許可しない入力を拒否する |
| ローカル判定 | `UrlRiskEvaluator` | URL文字列と厳しさから`SafetyLevel`を返す。safeは安全の保証ではない |
| 完全評価 | `URLEvaluationServiceProtocol` / `EnhancedUrlRiskEvaluator` | `evaluateComplete(url:completion:)`で外部照会を待つ。外部失敗/未知はfallbackとして保持 |
| Google照会 | `SafeBrowsingAPIClientProtocol` | `checkURL`はResult、`checkURLs`はURLごとのResultを返す。失敗をsafeへ置き換えない |
| 開封の状態管理 | `ScannerViewModel` | ready → processing → requiresConfirmationまたはopening。同じ判定への承認は一度だけ消費し、古い完了通知を無視する |
| タイトル | `HtmlTitleFetcherProtocol` | `fetchTitle(from:completion:)`。開封承認後だけ対象ホストへ通信し、タイトル取得のリダイレクトには追従しない |
| 履歴 | `HistoryRepositoryProtocol` / `HistoryRepository` | URLはString、Core Dataの`ScanRecord`へ保存。同一URLは更新・回数加算、最新50件まで。削除・全削除・タイトル更新 |
| 設定 | `SettingsStoreProtocol` | `SafetyStrictness`と外部照会ON/OFFを保存し、Combineで変更を通知する |

プロトコルの正本は[Common/Protocols.swift](../SafeQR/SafeQR/Common/Protocols.swift)。`ScanRecord`は公開structではなくCore Dataモデルである。

外部送信は[reputation-design.md](reputation-design.md)、通信の同意条件は[scan-consent-design.md](scan-consent-design.md)、ログは[logging-policy.md](logging-policy.md)を参照。
