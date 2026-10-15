# リリース前の検証記録

更新日：2026-10-15。公開判定は保留。CI成功や文書更新だけでIssue #8を閉じない。
アプリとUIテストの検証対象はPR #16の最終HEAD `9fdbdaed74a4928fd3c72742c31e98cc9361c2d9`。その後、アプリとUIテストを変更せず、CI改善のPR #18（最終HEAD `2e16b0cd2547e04c22d9aa538c448b0d1c6bb28e`）をmain `200fe60654095f04d2f0519f2c5c6e09cbb1b9e4`へ反映した。CI結果と公開前の未確認事項を以下で区別する。

## 環境と確認できた範囲

Xcode26.6 (17F113)、Swift6.3.3 / Swift5言語モード、macOS26.5.2。最低対応OSの設定は18.5。SwiftLint0.63.2 / SwiftFormat0.61.1を固定する。

| 項目 | 環境・結果 | 証跡 |
|---|---|---|
| 品質チェック | strict lint、format、ログ方針、plist検査がローカルと公開後CIで成功。CI改善後も全検証が成功 | [PR #16のCI](https://github.com/tashua314/safe-qr/actions/runs/38687487667)、[PR #18の最終CI](https://github.com/tashua314/safe-qr/actions/runs/38706185299)。検証ログと通常/カメラ拒否個別の両xcresultを保存・読み戻し済み |
| Debug / Release | iOS26.5 Simulatorの署名なしビルド成功 | ローカルbuild.log |
| iPhone全テスト | XCTest99件・Swift Testing1件・UI9件成功。通常スイートの権限拒否1件は個別実行へ分離 | 専用iPhone16Pro Simulator / iOS26.5 |
| 小画面と旧OS | 先行全テスト96件・追加1件・UI9件成功。Google案内/TTL修正後も関連単体15件・設定/詳細UI2件が成功 | 専用iPhone SE (3rd generation) / iOS18.6 |
| iPad操作 | 設定保存、警告、履歴再訪、詳細・横画面、全削除の取消/確定・空状態の3テスト成功。Google説明追加後にも同じ3件で成功 | iPad Pro 13-inch (M4) / iPadOS26.5 |
| カメラ拒否 | 専用SimulatorのOS権限をrevokeし、拒否案内→設定→履歴の1テスト成功（skip 0）。終了時にgrantへ戻した | `CameraPermissionUITests`個別実行 |
| 履歴 | in-memory単体テストで同一URLの更新・50件上限等を確認。操作テストで全削除の取消、削除、再表示後の空状態を確認 | `HistoryRepositoryTestsNew` / UIテスト |
| 同意と通信 | 承認前・拒否・履歴再訪・古い完了・遅い危険判定・HTTP302の通信契約をテスト。外部OFF・401/403等・未知/不正応答もモックで検証 | `ScanConsentTests` / `HtmlTitleRedirectTests` / SafeBrowsing系テスト |
| メモリ | resident_size取得失敗をテスト失敗とし、別途新規ViewModel/QR scanner service/評価器/title fetcherが解放されることを弱参照で確認 | `MemoryLeakTestsSimple`6件。DI解決の反復は短いsmokeテスト |
| Instruments | Release SimulatorへLeaksの60秒記録を試行したが、5分以上「Starting recording」のまま。中断し、有効な測定結果は得ていない | 実機Instruments・長時間測定は未完了 |
| 実機向けarchive | `generic/platform=iOS`のRelease archive成功。Bundle ID `jp.techguide.SafeQR`、version1.0/build1、iPhone/iPad、minimum18.5、PSL resourceを確認 | CODE_SIGNING_ALLOWED=NO。配布署名や提出の確認ではない |
| 本番API設定 | archiveの生成Info.plistはmissing。実キーの値を表示せず確認 | 認証・本番クォータは未確認 |
| アイコン | App Store用1024×1024 PNG、alphaなし、asset catalog登録あり | `Resources/Assets.xcassets/AppIcon.appiconset/icon.png` |
| 画面 | GitへPNG原本・状態・端末・サイズ・SHA-256を保存。PRの完全コミットSHA参照をGitHubから読み戻す | [画面記録](pr-captures/issue-8/README.md) |

## 今回直した問題

- 警告の詳細ボタンがアクセシビリティ要素から抜けていた。詳細とGoogle説明を読み取れるようにし、縦/横の短い画面でも開封・拒否へスクロールできるようにした。
- メモリ取得失敗を0MBに置き換えていた。測定失敗は失敗として扱い、共有DI参照の反復と新規インスタンスの解放を区別した。
- 履歴全削除の確認文の改行がリテラルだったため実改行へ修正した。
- Google由来の脅威警告だけに出典と脅威説明を表示する。利用開始前の設定と各Google警告に精度・信頼性の限界と誤判定・見逃しを案内する。陽性prefixは30分以内に再照会し、短いserver TTLと陰性prefixのTTLを保つ。[Google公式条件](https://developers.google.com/safe-browsing/terms)、[警告の案内](https://developers.google.com/safe-browsing/reference/Appropriate.Usage)
- README・CLAUDE・内部I/F・残タスクを現在のUIKit/Combine・v5・OS18.5へ合わせた。過去の98%や実機確認済みは現在の検証根拠に使わない。

## 公開前に残る条件

| 条件 | 現在の状態・次の確認 |
|---|---|
| 接続実機 | 利用者は接続・ロック解除の準備を回答。直近のdevicectlはiPhone12Proをunavailableと表示。利用可能になってから確認する |
| 実機の基本操作 | カメラの初回許可/拒否、実QR、ライト、警告の承認/拒否、履歴、設定保存、オフラインを確認する。Simulatorの模擬URLで代用しない |
| 長時間・性能 | 実機で長時間スキャン/遷移とInstruments、メモリ推移・発熱/バッテリー・処理時間を記録する。短い単体テストや起動性能の平均で代用しない |
| 本番通信 | Git管理外キーを設定し、Google認証・クォータ・実際の送信と承認/拒否時の通信を実機で確認する。キーをチャット・GitHub・ログに記載しない |
| 配布 | iOS用の署名・provisioning・archive export/実機インストールを確認する。今回の署名なしarchiveを配布成功と扱わない |
| 申請情報 | 運営者名、連絡先、サポートURL、プライバシー公開URLは利用者回答で未定 |
| 配布条件 | 当面は収益化せず、収益化開始前にWeb Riskへ移行・検証を完了する方針。実際の用途と非商用条件の適合、地域・年齢・規約/EULAは公開前に確定する。売上0だけで非商用と断定しない |
| ストア画像 | QAのPNGは下書き。実機カメラのモックを実機撮影として提出しない。最新のApple仕様を確認し、状態・説明を整えてから申請する |

[申請文](app-store-description.md)、[機械可読メタデータ](app-store-metadata.json)、[プライバシー](privacy-policy-draft.md)、[規約](terms-draft.md)は下書き。App Store Connectへの入力、署名アップロード、審査提出は行っていない。

## 再実行

通常は`make tools && make check`。別の検証専用Simulatorは`SAFEQR_SIMULATOR_ID=<UUID> make check`を使う。同じSimulatorに同時に複数のxcodebuild testを実行しない。

`make check`とCIは、通常スイートで権限拒否1件を意図的にskipした後、専用Simulatorの権限を変更して同ケースを個別実行する。単独で実行する場合も、実行前にcameraをrevokeし、終了時のtrapでgrantへ戻す。テストrunnerへ`TEST_RUNNER_SAFEQR_TEST_CAMERA_DENIED=1`を渡し、`-only-testing:SafeQRUITests/CameraPermissionUITests`を指定する。個別実行のskipが0であることを確認する。

画像は`.xcresult`のattachmentsから書き出し、目視確認してGitへ保存する。XCTestの一時パスやCI Artifactの期限付きURLだけをPRの画像参照先にしない。
