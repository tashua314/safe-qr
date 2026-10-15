# SafeQR — iOS 18.5+ QRコードリーダー

「ITリテラシー低めの方でも迷わず安全に使える」ことを最優先にした、シンプルなQRコードリーダー。

- 最低対応OS: **iOS 18.5**（UIKitベース、SceneDelegate対応）
- スキャン: **AVFoundation / AVCaptureMetadataOutput**
- ブラウズ: **SFSafariViewController**
- 履歴: **Core Data**（最大50件、端末内のみ）
- 危険判定: 端末内ヒューリスティック + **外部レピュテーション照会（任意ON）**
- テレメトリ: 匿名クラッシュ収集（Apple標準）有効
- 法務表記: **不要**

## プロジェクト概要

- 名称：SafeQR
- 目的：ITリテラシーが高くない方でも、迷わず・安全にQRコードからリンクを開ける
- 最低対応OS：**iOS 18.5**
- 主要機能
  - QRスキャン（起動＝即スキャン）
  - **危険判定**（端末内ヒューリスティック＋外部レピュテーション）
  - **履歴（最大50件）**：タイトル付き、端末内保存のみ
  - アプリ内安全ブラウズ（SFSafariViewController）
  - 設定（安全確認の厳しさ・外部照会ON/OFF）
- 非機能
  - アクセシビリティ（Dynamic Type/コントラスト/VoiceOver説明文）
  - パフォーマンス（軽量・即応答）
  - プライバシー（Google安全性照会はSHA-256の先頭4バイトのみ。タイトル取得・ブラウザ表示は対象サイトへ通信）

## ディレクトリ構成（実装版）

```
SafeQR/SafeQR/
├─ AppDelegate.swift              # アプリライフサイクル管理
├─ SceneDelegate.swift            # 画面・ウィンドウ管理（iOS 13+）
├─ Info.plist                     # アプリ設定（カメラ権限等）
│
├─ Presentation/                  # UI層（UIKit）
│   ├─ ScannerViewController.swift      # QRスキャナー画面（メイン画面）
│   ├─ HistoryViewController.swift      # 履歴一覧・管理画面  
│   ├─ SettingsViewController.swift     # 設定画面（安全性レベル調整）
│   └─ OpenConfirmViewController.swift  # URL開封確認ダイアログ
│
├─ Domain/                        # ビジネスロジック・ドメインモデル
│   ├─ Entities/
│   │   └─ ScanRecord.swift             # スキャン履歴エンティティ
│   ├─ Safety/
│   │   ├─ SafetyLevel.swift            # 安全性レベル定義（safe/caution/danger）
│   │   └─ UrlRiskEvaluator.swift       # URL危険度判定エンジン
│   └─ Repositories/
│       └─ HistoryRepository.swift      # 履歴データ操作（Core Data抽象化）
│
├─ Data/                          # データアクセス・外部連携層
│   ├─ CoreData/
│   │   ├─ CoreDataStack.swift          # Core Data管理・初期化
│   │   └─ SafeQR.xcdatamodeld/         # データモデル定義
│   ├─ Metadata/
│   │   └─ HtmlTitleFetcher.swift       # Webページタイトル後追い取得
│   └─ Reputation/
│       └─ ReputationClient.swift       # 外部レピュテーション照会（オプション）
│
├─ Services/                      # 各種サービス・ユーティリティ
│   ├─ QR/
│   │   └─ QRScannerService.swift       # AVFoundation QRスキャン機能
│   └─ Settings/
│       └─ SettingsStore.swift          # アプリ設定管理（UserDefaults）
│
├─ Resources/                     # リソースファイル
│   ├─ Assets.xcassets/                 # アプリアイコン・画像アセット
│   └─ LaunchScreen.storyboard          # 起動画面
│
└─ SafeQRTests/                   # ユニットテスト
    ├─ UrlRiskEvaluatorTests.swift      # 危険度判定ロジックのテスト
    ├─ HistoryRepositoryTests.swift     # 履歴管理機能のテスト
    └─ SafeQRTests.swift                # 基本テスト
```

### アーキテクチャ

**Clean Architecture** ベースの3層構成：
- **Presentation層**: UIKit ベースのビューコントローラー群
- **Domain層**: ビジネスロジック（URL危険度判定・履歴管理等）
- **Data層**: Core Data、外部API、メタデータ取得

## 現在の実装状況
- ✅ **基本機能完了**: QRスキャナー、危険度評価、履歴管理、設定画面
- ✅ **SceneDelegate対応**: iOS 13+ の新しいアプリライフサイクル
- ✅ **シミュレータ対応**: カメラが使えない環境でのテスト機能
- ✅ **UIタッチ最適化**: 各ビューのタッチイベント処理を調整済み
- ✅ **文字列補間修正**: 履歴画面の訪問回数表示を修正済み

## ビルド・実行方法
1. Xcode でプロジェクトを開く
2. シミュレータまたは実機を選択
3. ビルド・実行（`Cmd+R`）
4. シミュレータでは「テスト QR スキャン」ボタンでテスト可能

## ドキュメント
`/docs` 以下に詳細な仕様や設計ドキュメントがあります。

## 外部安全性チェックと通信

既定ではOFFです。ON時はGoogle Safe Browsing v5の `hashes.search` を使用し、端末で正規化したURLから最大30候補を生成して、SHA-256の先頭4バイト（base64）だけを送ります。返された完全ハッシュを端末内で照合し、Googleが指定した有効期限を使ってメモリ内に保存します。URL全文や完全ハッシュは照会リクエストに含めません。

ハッシュの一部から候補が推測される可能性があり、GoogleにはIP等の通信情報も届きます。タイトル取得・ページを開く操作は対象サイトへ通信します。安全判定は無害性の保証ではありません。詳しくは [照会設計](docs/reputation-design.md) と [プライバシーポリシー下書き](docs/privacy-policy-draft.md) を参照してください。
