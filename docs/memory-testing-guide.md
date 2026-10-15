# メモリ・長時間動作の検証ガイド

更新日：2026-10-15。実施結果は[検証記録](release-validation.md)、最新の進行状況は[Issue #8](https://github.com/tashua314/safe-qr/issues/8)へ記録する。手順があることを測定成功の根拠にしない。

## 単体テストで分かる範囲

現存するテストは `SafeQR/SafeQRTests/MemoryLeakTestsSimple.swift` の6件。

| テスト | 確認範囲 |
|---|---|
| `testDIContainerMemoryManagement` | DI解決の反復smoke。factoryや全オブジェクトの解放証明ではない |
| `testCoreDataStackMemoryManagement` | 履歴取得の反復smoke。失敗をログへ出すだけの経路もあり、Core Data全体の解放証明ではない |
| `testViewModelMemoryManagement` | ViewModel生成の反復smoke |
| `testServiceMemoryManagement` | サービス生成の反復smoke。実カメラの連続稼働ではない |
| `testAggregateMemoryManagement` | テストプロセスのresident_size増分を短いバッチで検査。取得失敗はthrow、増分は30MiB未満をassert。30秒・30分の計測ではない |
| `testIndependentComponentsAreReleased` | 新規ViewModel、QRScannerService、EnhancedUrlRiskEvaluator、HtmlTitleFetcherを弱参照し破棄を確認。画面Controllerや実稼働中カメラの解放確認ではない |

通常の検証は `make tools` の後に `make check`。限定実行は、検証専用SimulatorのUUIDを設定して以下を使う。同じSimulatorへ同時に別のテストを実行しない。

```bash
SAFEQR_SIMULATOR_ID='<検証専用Simulator UUID>'
xcodebuild -project SafeQR/SafeQR.xcodeproj -scheme SafeQR \
  -destination "platform=iOS Simulator,id=$SAFEQR_SIMULATOR_ID" \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:SafeQRTests/MemoryLeakTestsSimple test
```

## 実機測定の準備

1. 署名付きReleaseを実機へインストールし、ソースのコミット・ビルド構成・端末/OS・開始日時を記録する。開発用exportをApp Store配布成功と扱わない。
2. USB接続・ロック解除・信頼・開発者モードを確認する。`xcrun devicectl list devices` と `xcrun xctrace list devices` で現在の接続を確認する。端末詳細の取得だけでは、キャッシュされた情報を実接続と誤認する場合がある。
3. ミラーリングを終了し、実カメラ映像を確認する。測定中に画面がロックされたり、別アプリへ移ったりした時間は記録する。
4. 照明・画面輝度・ライト・外部チェック設定、通信、充電/ケーブル接続、電池残量、他アプリの使用状況を記録する。USB給電中の電池残量変化から、非充電時の消費を推定しない。
5. 履歴を消す再インストールや、他アプリにも影響するプライバシー設定のリセットを無断で行わない。

## Instrumentsの記録

InstrumentsのActivity Monitorで対象端末とSafeQRプロセスを選ぶ。CLIを使う場合は、Instrumentsに表示される端末UDIDを指定する。CoreDeviceのUUIDと取り違えない。

```bash
umask 077
mkdir -p .artifacts/device-qa
SAFEQR_DEVICE_UDID='<Instrumentsで確認した実機UDID>'
xcrun xctrace record --template 'Activity Monitor' \
  --device "$SAFEQR_DEVICE_UDID" --attach SafeQR \
  --time-limit 30m --output .artifacts/device-qa/camera-30m.trace
```

最初の10分記録は疎通・予備測定とし、30分連続使用の判定とは区別する。既存traceを上書きせず、再実行時は別の出力名を使う。起動前からの割当が必要な場合はInstrumentsの起動計測を選ぶ。

基本シナリオは、カメラ待機2分、QR読み取り10回、履歴の開閉5回、設定の開閉5回、危険/注意の拒否各5回、カメラ待機3分。各操作の時刻と所要時間を記録する。製品版にはテストQRボタンがないため、公開テスト用QRを別画面に表示して実カメラで読む。初回の10分でこの全操作を行っていなければ、カメラ待機の測定として記録する。

その後、30分連続使用の記録と、50回スキャン、履歴50件、バックグラウンド復帰10回、外部チェックON/OFF10回などの負荷シナリオを区別して実施する。権限の変更は測定シナリオへ明記し、終了時に元へ戻す。対象サイトを開かない試験では拒否を選ぶ。

LeaksとAllocationsは別の記録として実施する。GUIのテンプレートから開始できるほか、既に動作している対象への短い接続確認は次のように行う。接続確認だけで長時間のリークなしを主張しない。

```bash
xcrun xctrace record --template 'Leaks' \
  --device "$SAFEQR_DEVICE_UDID" --attach SafeQR \
  --time-limit 1m --output .artifacts/device-qa/leaks-connection.trace
```

- Leaksの記録完了・対象PID・有効な検査回数と検出内容を確認する。接続断、開始待ち、空の結果を「0件」へ変換しない。
- Allocationsでは起動後、10/20/50回スキャン後に世代を分け、残存割当と解放を確認する。
- Activity Monitorでは対象PIDのメモリ/CPU時系列と実測期間を確認する。一点のMemory表示から最小・最大・平均や傾向を推定しない。
- `xctrace export` がこの環境でexit139・空XMLになった場合、結果なしとしてInstruments GUIでtraceを開く。正常終了と非空の出力を確認せず集計しない。GUIでも必要な時系列が取得できなければ未測定として残す。
- 温度/電池/エネルギー、URL評価時間、UI応答時間は別々の指標。API応答時間や起動性能の平均でUI応答時間を代用しない。発熱の利用者所見と計測された温度も区別する。

## 既存の内部目標と判定

以下は既存ガイドの内部目標。実機で未測定の項目を合格にしない。MBとMiBを混在させず、同じ指標・単位へ換算して比較する。

| 指標 | 既存の目標 |
|---|---|
| 起動時メモリ | 50MB未満 |
| QRスキャン中メモリ | 100MB未満 |
| 10分使用後の増分 | 起動時から20MB未満（50MB以上は警告、100MB以上は危険） |
| 50回スキャン後の増分 | 起動時から30MB未満（70MB以上は警告、150MB以上は危険） |
| 30分連続使用後の増分 | 100MB未満 |
| CPU | 待機中5%未満、スキャン中30%未満、URL評価中15%未満 |
| UI応答時間 | 100ms未満 |
| Leaks | 有効な検査で検出0件 |
| その他 | 復帰後の動作、メモリ警告への対応、発熱/バッテリーを確認 |

## 残す証跡

対象ソース、構成、端末/OS、設定、実測開始/終了、操作回数、対象PID、測定ツール、メモリ指標/単位、開始/終了/ピーク/傾向、CPU、Leaks結果、電池/充電条件、発熱所見、各失敗を記録する。記録を読んだ範囲だけを結果にする。

生trace・端末識別番号・APIキーはGitHubへ出さない。共有する集計とキャプチャは個人情報や秘密値がないことを確認し、画像はGit保存・完全コミットSHA固定リンクにする。期限付きArtifact URLや一時ファイルだけを公開証跡にしない。
