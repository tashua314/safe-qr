# タスクリスト（iOS10 / UIKit）

> 目的：iOS10対応のシンプル＆安全なQRリーダーの叩き台を最短で生成

## 0) プロジェクト雛形
- 新規 iOS アプリ（Objective-Cは不要、**Swift**）
- 最低OS **iOS 10.0**
- ライフサイクル: AppDelegate + Storyboard無し（コードでUI構築）
- 依存: 純正フレームワークのみ（AVFoundation, SafariServices, CoreData）

## 1) ファイル作成（この順で最低限可動まで）
- App/AppDelegate.swift（rootをScannerViewControllerに）
- Services/QR/QRScannerService.swift（AVCaptureSession/AVCaptureVideoPreviewLayer/AVMetadataOutputでQRCode検出）
- Domain/Safety/SafetyLevel.swift（safe/caution/danger）
- Domain/Safety/UrlRiskEvaluator.swift（docs/safety-design.md のスコアリング実装）
- Presentation/ScannerViewController.swift
  - カメラプレビュー全画面＋シンプルなガイド
  - URL検出→UrlRiskEvaluator→必要時OpenConfirmViewController表示
  - 開く時は SFSafariViewController 経由
  - 取得URLを HistoryRepository 経由で保存（後追いタイトル取得はキックのみ）
- Data/CoreData/CoreDataStack.swift（軽量でOK）
- Data/CoreData/ScanRecordEntity（xcdatamodeld）: docs/db-design.md 準拠
- Domain/Repositories/HistoryRepository.swift（最大50件ルール＋重複扱い）
- Presentation/HistoryViewController.swift（UITableView）
- Data/Metadata/HtmlTitleFetcher.swift（timeout短め、<title>抽出）
- Presentation/SettingsViewController.swift（厳しさ: low/standard/high、外部照会ON/OFF）
- Presentation/OpenConfirmViewController.swift（優しい文章と2ボタン）

## 2) 受入れ観点（Doneの定義）
- 起動直後にスキャン開始（許可未取得なら許可導線）
- URL検出→危険/注意は確認画面、safeはそのまま開ける
- 履歴に最大50件保存（51件目で一番古いもの削除）
- タイトル後追い取得が成功すればリスト反映
- Dynamic Type拡大で主要画面が破綻しない
- オフラインでもスキャン/保存は動作（タイトル取得/外部照会は待機）

## 3) 実装メモ
- AVFoundation: iOS10で動く `AVCaptureMetadataOutputObjectsDelegate` を使用
- UI: AutoLayoutはコード。配色/文言は docs/ui-design.md を参照
- 外部レピュテーション: `ReputationClient` はダミーのモック実装→後で実エンドポイント差し替え
- 機微情報送信なし。URLの**生文字列は外部送信しない**（ハッシュ化/ドメインのみ）

## 4) テスト
- UrlRiskEvaluatorTests: 代表URLで safe/caution/danger が期待通り
- HistoryRepositoryTests: 50件上限ローテーション、重複URLのvisitCount加算

> 以上を順に生成→ビルド通過→シミュレータでカメラは不可（実機で確認）。UIはモック画像でもOK。
