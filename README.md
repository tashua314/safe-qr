# SafeQR

QRコードのURLを開く前に危険度を確認するiPhone/iPadアプリ。最低対応OSは **iOS/iPadOS 18.5**。安全性の保証ではなく、端末内のルールと任意のGoogle Safe Browsing照会で注意を促す。危険なサイトの見逃しや、害のないサイトへの誤警告が起こる可能性がある。

## 実装

- UIKit、Swift5言語モード、SceneDelegate。画面はコードで構築し、起動画面だけStoryboardを使う。
- AVFoundationでQRを読み取り、`ScannerViewModel`が完全評価・確認・開封の状態を管理する。Combineで各画面に通知する。
- Core Dataの履歴は最大50件。同じURLの再スキャンは回数と日時・危険度を更新する。拒否したスキャンもタイトルなしで残す。
- 注意・危険・外部チェック未確認では開封を選ぶまで対象サイトへ通信しない。履歴からの再訪も再評価する。
- 開封を許可した後にだけタイトルを取得する。タイトル取得はHTTPリダイレクトを追わない。ページ表示はSFSafariViewController。
- 外部チェックは既定OFF。ON時はURL候補のSHA-256先頭4バイト（base64）をv5 `hashes.search`へ送信し、完全ハッシュを端末内で比較する。URL全文はGoogleへ送らないが、IP等の通信情報は届き、prefixから候補が推測される可能性もある。
- タイトル取得・ブラウザー表示は対象サイトへURLで通信する。ログは定義済みイベント・数値コード・処理時間だけ。独自の解析送信は実装していない。OSの診断は利用者のOS設定による。

## 開発と検証

```sh
open SafeQR/SafeQR.xcodeproj
make tools
make check
```

`make tools`でSwiftLint0.63.2 / SwiftFormat0.61.1をチェックサム検証して`.artifacts/tools`へ配置する。`make check`は静的チェック、Debug/Releaseの署名なしSimulatorビルド、専用iPhone Simulatorの単体・UIテストを実行する。成果物とログはGit管理外の`.artifacts`へ保存する。

外部照会のキーは[設定手順](SafeQR/Config/README.md)に従い、Git管理外の`Local-Keys.xcconfig` / `Production-Keys.xcconfig`へ設定する。未設定でもビルドでき、設定未完了を未確認として扱う。実キーをコマンド引数・ログ・Issueへ記載しない。

Simulatorにはカメラの代わりに`.invalid`テストURL用ボタンを表示する。実カメラ・ライト・長時間動作・バッテリー・本番API認証の確認を代用しない。

## 構成

| 場所 | 責務 |
|---|---|
| `SafeQR/SafeQR/Presentation` | UIKit画面、ViewModel、UI状態 |
| `SafeQR/SafeQR/Domain` | ローカル危険度と履歴モデル・操作 |
| `SafeQR/SafeQR/Data` | Core Data、HTMLタイトル、Safe Browsing v5 |
| `SafeQR/SafeQR/Services` | QR検出とUserDefaults設定 |
| `SafeQR/SafeQR/Common` | DI、プロトコル、定数、最小診断ログ |
| `SafeQR/SafeQRTests` / `SafeQR/SafeQRUITests` | 単体・通信契約・画面操作の検証 |

実際の外部判定は`EnhancedUrlRiskEvaluator`→`SafeBrowsingAPIClient`を使う。`ReputationClient`は旧モックで、現在のスキャン経路には接続していない。

## 公開前の状態

[検証結果と残条件](docs/release-validation.md)、[タスク](docs/tasks.md)を参照。実機・署名配布・本番認証・申請情報が揃うまで公開可能とは扱わない。ストア説明、プライバシー、利用規約は下書きで、運営者・窓口・公開URLは未定。

- [ビルドと権限](docs/build-and-permissions.md)
- [安全判定](docs/safety-design.md) / [外部照会](docs/reputation-design.md)
- [通信と開封確認](docs/scan-consent-design.md) / [ログ](docs/logging-policy.md)
