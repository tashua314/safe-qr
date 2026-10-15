# リリース前の検証記録

更新日：2026-10-16。公開判定は保留。CI成功や文書更新だけでIssue #8を閉じない。
最新のAPI検証ソースはPR #24の最終HEAD `6bd50d1666e848140bebc20b8e5bac4def6f156b`。独立レビューとCI成功後にmain `5e1a783071b1b875fb55960e48b30efc7579dd32`へマージし、tree一致を確認した。以下では過去のSimulator確認、今回の実機/API確認、未完了条件を区別する。最新の進行状況は[Issue #8](https://github.com/tashua314/safe-qr/issues/8)も参照する。

先行するPR #16の対象HEADは `9fdbdaed74a4928fd3c72742c31e98cc9361c2d9`。CI改善PR #18の最終HEADは `2e16b0cd2547e04c22d9aa538c448b0d1c6bb28e`。その後のAPI互換修正でアプリとテストを変更しているため、先行テストを最終ソースの全端末確認へ読み替えない。

レイアウト循環の修正は[PR #28](https://github.com/tashua314/safe-qr/pull/28)、対象HEAD `d13c1ff348253bf4708c6825fcc5b308eaa0ec98`。独立レビュー承認と[CI全3ジョブ成功](https://github.com/tashua314/safe-qr/actions/runs/38748795685)後にmain `9e3a62d4347cf05a7c9d8bd654840ae0151683d9`へマージし、レビュー/CI済みtreeとの一致を確認した。実機にインストールした版は修正前であり、修正後の実機CPU改善は未確認。

2026-10-15、利用者の「負荷テストはスキップでOK」により、30分連続使用・多数回スキャン・繰り返し遷移などの負荷シナリオは未実施のまま省略した。合格とは扱わず、実施待ちを公開準備の条件から外す。既存の自動回帰テスト・レビュー・CIは維持する。

2026-10-16、最新main `b3c7b9f5afbff22df93c85bcdf88a99f9ee37f16` からローカルの署名付きRelease archiveを生成した。codesignのdeep/strict検証、Bundle ID `jp.techguide.SafeQR`、version1.0/build1、minimum18.5、profileのBundle ID一致と有効期限、本番キーの設定一致（値は非公開）、UserDefaults / CA92.1のmanifest同梱を確認。使用したのは開発用署名で、App Store配布用のexport・アップロード・審査提出はしていない。実機インストール/起動・CPU再測定も行っていない。

## 環境と確認できた範囲

Xcode26.6 (17F113)、Swift6.3.3 / Swift5言語モード、macOS26.5.2。最低対応OSの設定は18.5。SwiftLint0.63.2 / SwiftFormat0.61.1を固定する。

| 項目 | 環境・結果 | 証跡 |
|---|---|---|
| 品質チェック | strict lint、format、ログ方針、plist検査がローカルと公開後CIで成功。CI改善後も全検証が成功 | [PR #16のCI](https://github.com/tashua314/safe-qr/actions/runs/38687487667)、[PR #18の最終CI](https://github.com/tashua314/safe-qr/actions/runs/38706185299)。検証ログと通常/カメラ拒否個別の両xcresultを保存・読み戻し済み |
| Debug / Release | iOS26.5 Simulatorの署名なしビルド成功 | ローカルbuild.log |
| 先行iPhone全テスト | XCTest99件・Swift Testing1件・UI9件成功。通常スイートの権限拒否1件は個別実行へ分離 | PR #16の専用iPhone16Pro Simulator / iOS26.5 |
| 最新API修正の全体CI | XCTest113件・Swift Testing1件・UI9件成功。分離したカメラ拒否も個別1件成功・skip0。全3ジョブ成功、成果物のログと両xcresultを読み戻した | [PR #24のCI](https://github.com/tashua314/safe-qr/actions/runs/38735335577)。iOSジョブ14分47秒、check.shは854秒 |
| レイアウト循環の修正 | 修正前の待機100msに追加レイアウト1,163回を再現。修正後は新規2件を含むXCTest115件・Swift Testing1件・UI9件、カメラ拒否個別1件（skip0）がローカルで成功。lint/format・Debug/Releaseも成功。CIでも全件成功し、保存ログと通常/拒否個別の両xcresultを読み戻した | iPhone16Pro / iOS26.5 Simulator、PR #28の対象HEAD。CIのcheck.shは926秒、iOSジョブ16分15秒。実機CPU改善の証明ではない |
| 小画面と旧OS | 先行全テスト96件・追加1件・UI9件成功。Google案内/TTL修正後も関連単体15件・設定/詳細UI2件が成功 | 専用iPhone SE (3rd generation) / iOS18.6 |
| iPad操作 | 設定保存、警告、履歴再訪、詳細・横画面、全削除の取消/確定・空状態の3テスト成功。Google説明追加後にも同じ3件で成功 | iPad Pro 13-inch (M4) / iPadOS26.5 |
| カメラ拒否 | 専用SimulatorのOS権限をrevokeし、拒否案内→設定→履歴の1テスト成功（skip 0）。終了時にgrantへ戻した | `CameraPermissionUITests`個別実行 |
| 履歴 | in-memory単体テストで同一URLの更新・50件上限等を確認。操作テストで全削除の取消、削除、再表示後の空状態を確認 | `HistoryRepositoryTestsNew` / UIテスト |
| 同意と通信 | 承認前・拒否・履歴再訪・古い完了・遅い危険判定・HTTP302の通信契約をテスト。外部OFF・401/403等・未知/不正応答もモックで検証 | `ScanConsentTests` / `HtmlTitleRedirectTests` / SafeBrowsing系テスト |
| メモリ | resident_size取得失敗をテスト失敗とし、別途新規ViewModel/QR scanner service/評価器/title fetcherが解放されることを弱参照で確認 | `MemoryLeakTestsSimple`6件。DI解決の反復は短いsmokeテスト |
| 先行Instruments | 旧main `78f4fed` の実機ReleaseでActivity Monitor記録成功。GUI run 00:01:01、Memory表示27.64MiB。最小/最大/平均や長時間推移の確認ではない。実機Leaksは接続断exit2、CLI exportはexit139・空XML。Simulator Leaksも開始待ちを中断 | GUIで短時間traceを読んだ。長時間・リーク0・CPU/発熱/電池の判定は未完了 |
| 実機10分待機 | カメラ表示・ライトOFF、Activity Monitorが時間上限で正常終了。全586行・連続601.3955秒・区間欠落なしを検査。physical footprintは開始14.236MiB、終了17.127MiB、増分2.891MiB、最小12.408MiB、最大27.846MiB。CPU585サンプルは標本平均100.103%、最小95.576%、最大101.766% | iPhone12Pro / iOS27.0.1、署名Release、アプリコードはPR #24最終HEADと同一。CPUはInstrumentsのプロセス表示。詳細と未確認範囲は[#27](https://github.com/tashua314/safe-qr/issues/27) |
| 実機向けRelease | Apple Account再ログイン後に自動開発署名でDebug/Releaseをビルド。Release archive、開発用IPA export、codesignと対象実機登録、実機インストール・通常起動を確認。最終APIソースでも本番キー入りReleaseで成功 | iPhone12Pro / iOS27.0.1。開発用export（method=debugging）でありApp Store配布・提出の確認ではない |
| 本番API設定 | 専用Cloudプロジェクト、開発/本番キーを作成。Safe Browsing APIとBundle IDへ制限し、Git管理外xcconfig（600）で接続。生成plistのconfiguredと本番キー一致を値なしで検査。課金関連付けなし・既定クォータを読み戻した | [#21 / PR #22](https://github.com/tashua314/safe-qr/pull/22)、[#23 / PR #24](https://github.com/tashua314/safe-qr/pull/24)。両PRは独立レビュー・CI後にマージ |
| 実APIの7ケース | 本番/開発キー200、公開フィッシングの完全ハッシュ一致、通常URL一致なし、Bundle ID未送信/不一致403、不正キー400が成功。アプリと同じSwift正規化/hash生成とProtobufデコーダーを使用 | ホストからのHTTPS照会。実機のパケット監査や実APIを枯渇させる429試験ではない |
| 実機の基本操作 | Debugでカメラ、注意/危険QR・拒否後履歴、ライト、強設定の再起動後保持、ブラウザ復帰/再読、オフライン、カメラ設定OFF時の履歴/設定を利用者が確認。旧Releaseのカメラ・注意QR・キャンセル・履歴保持も確認 | iPhone12Pro / iOS27.0.1、旧main `78f4fed`。初回拒否は次項の別Bundle IDで確認 |
| 実機の初回カメラ拒否 | 同じReleaseソース `f508bebfc45a2d7f338a97fd1aecf8fe02c1c6b4` を別Bundle ID・表示名「SafeQR 権限確認」・APIキーなしで生成。新規インストール状態で利用者が「許可しない」→設定案内→キャンセル後の履歴/設定を確認。終了後はQA版だけアンインストール | iPhone12Pro / iOS27.0.1。通常版の履歴・権限は保持し、通常版Bundle IDの権限リセット試験とは区別する |
| 実機の本番API | 最終APIソースの署名Releaseで、利用者が外部チェックONのGoogle危険警告・出典・ブロックを確認。アプリ終了→通信OFF→再起動後は未確認表示・キャンセル、確認後の通信復元も確認 | iPhone12Pro / iOS27.0.1。利用者操作の確認。Debugの全チェックリストのRelease再実施ではない |
| アイコン | App Store用1024×1024 PNG、alphaなし、asset catalog登録あり | `Resources/Assets.xcassets/AppIcon.appiconset/icon.png` |
| 画面 | GitへPNG原本・状態・端末・サイズ・SHA-256を保存。PRの完全コミットSHA参照をGitHubから読み戻す | [画面記録](pr-captures/issue-8/README.md) |

10分記録の開始値は起動・測定準備後で、cold launch全体ではない。利用者は映像停止や気になる発熱について「特に気にならなかった」と回答したが、温度・UI遅延の計測値ではない。USB給電下なので電池消費は判定していない。先行の10分試行は切断でrun 00:04:04 / Process HistoryはNo Dataだったため失敗扱いとし、今回の成功記録と混同しない。Leaksは有効な結果がなく、0件とは判定しない。集計値と端末モデル/OSは利用者の公開許可後にIssueへ記録した。生trace・端末ID・APIキーは公開しない。

## 今回直した問題

- 警告の詳細ボタンがアクセシビリティ要素から抜けていた。詳細とGoogle説明を読み取れるようにし、縦/横の短い画面でも開封・拒否へスクロールできるようにした。
- メモリ取得失敗を0MBに置き換えていた。測定失敗は失敗として扱い、共有DI参照の反復と新規インスタンスの解放を区別した。
- 履歴全削除の確認文の改行がリテラルだったため実改行へ修正した。
- Google由来の脅威警告だけに出典と脅威説明を表示する。利用開始前の設定と各Google警告に精度・信頼性の限界と誤判定・見逃しを案内する。陽性prefixは30分以内に再照会し、短いserver TTLと陰性prefixのTTLを保つ。[Google公式条件](https://developers.google.com/safe-browsing/terms)、[警告の案内](https://developers.google.com/safe-browsing/reference/Appropriate.Usage)
- README・CLAUDE・内部I/F・残タスクを現在のUIKit/Combine・v5・OS18.5へ合わせた。過去の98%や実機確認済みは現在の検証根拠に使わない。

## 公開前に残る条件

| 条件 | 現在の状態・次の確認 |
|---|---|
| 接続実機 | 実機のpaired/wired/connectedと起動を確認済み。再測定の直前にも現在の接続・ロック状態を確認する |
| 性能の確認範囲 | 30分連続や多数回スキャン等の負荷テストは利用者判断で省略。実機10分待機の記録とレイアウト循環修正の回帰テストは確認済み。修正後の実機CPU、Leaks、温度・電池・UI遅延は未確認のまま残す |
| 通信の確認範囲 | 本番認証と実機オンライン/オフラインは確認済み。OFF/同意/拒否・prefix限定・リダイレクト拒否・429等の失敗は自動テスト。実機の全通信を取得するパケット監査やクォータ枯渇試験は未実施 |
| 配布 | 開発用署名・export・実機インストール/起動は確認済み。App Store向け配布・TestFlight・アップロード・審査提出は未実施 |
| 申請情報 | 運営者はTechGuide合同会社、問い合わせ先はy.takahashi@techguide.jpと利用者確認済み。[サポート](https://techguide.jp/safeqr/)・[プライバシー](https://techguide.jp/safeqr/privacy/)はcorporate PR #63を独立レビュー/CI後にマージし、Amplify job69成功と2026-10-16のHTTP200を確認済み。審査用氏名/電話等は未確定 |
| 配布条件 | 当面は収益化せず、収益化開始前にWeb Riskへ移行・検証を完了する方針。実際の用途と非商用条件の適合、地域・年齢・規約/EULAは公開前に確定する。売上0だけで非商用と断定しない |
| ストア画像 | [候補一覧](app-store-assets-draft.md)にiPhone2枚・iPad2枚を整理。iPadはRelease・カメラ拒否状態の設定/模擬履歴を撮影し、テストUI写り込みなし。全候補の寸法・alphaなし・SHA256を確認済み。掲載画像の最終採否は未確定。QAのPNGは下書き。実機カメラのモックを実機撮影として提出しない。最新のApple仕様を確認し、状態・説明を整えてから申請する |

年齢・App Privacyの[回答案](app-store-questionnaire-draft.md)は実装とApple公式資料から準備した下書き。年齢やデータ収集/トラッキングの最終回答、App Store Connectでの保存・提出を確定したものではない。

[申請文](app-store-description.md)、[機械可読メタデータ](app-store-metadata.json)、[プライバシー](privacy-policy-draft.md)、[規約](terms-draft.md)は下書き。App Store Connectへの入力、署名アップロード、審査提出は行っていない。

## 再実行

実機測定を再開する場合は[メモリ・長時間動作の検証ガイド](memory-testing-guide.md)を使う。今回省略した負荷テストの実施を要求するものではない。短い記録や失敗を長時間合格へ変換しない。

通常は`make tools && make check`。別の検証専用Simulatorは`SAFEQR_SIMULATOR_ID=<UUID> make check`を使う。同じSimulatorに同時に複数のxcodebuild testを実行しない。

`make check`とCIは、通常スイートで権限拒否1件を意図的にskipした後、専用Simulatorの権限を変更して同ケースを個別実行する。単独で実行する場合も、実行前にcameraをrevokeし、終了時のtrapでgrantへ戻す。テストrunnerへ`TEST_RUNNER_SAFEQR_TEST_CAMERA_DENIED=1`を渡し、`-only-testing:SafeQRUITests/CameraPermissionUITests`を指定する。個別実行のskipが0であることを確認する。

画像は`.xcresult`のattachmentsから書き出し、目視確認してGitへ保存する。XCTestの一時パスやCI Artifactの期限付きURLだけをPRの画像参照先にしない。
