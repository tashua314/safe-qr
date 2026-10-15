# Issue #7の画面と操作確認

2026-10-15、Xcode 26.6 / iOS 26.5 / 専用iPhone 16 Pro Simulator、Debug、縦向き1206×2622 pixels、ダーク表示。画像はXCTestの実際の画面キャプチャを抽出したもの。検証用ドメインは予約された `.invalid` を使用する。

## 実行した操作

`testSettingsHistoryAndMockScanWarnings` で以下を実行し、表示と操作のassertionを確認した。全ユニット40件・Swift Testing1件・UI6件を含む `make check` は成功。キャプチャを縦向きに固定し、強・外部ONが保存された状態からの再実行（1件）も成功した。

1. スキャン画面を起動し、テストスキャンボタンの表示を確認。
2. 強・外部チェックONを保存して再起動し、保存を確認。その後、標準・OFFを明示選択して設定を確認し、閉じる。
3. 注意テストURLをスキャンし、「不審な可能性があります」警告を表示。「やめる」でスキャン画面へ戻る。
4. 危険テストURLをスキャンし、「危険な可能性があります」警告を表示。「ブロックする」で戻る。
5. 履歴を開き、両スキャンの項目を確認して閉じる。

Simulatorのテストボタンが、画面の監視するpublisherへ結果を送っていなかった既存の接続を復旧した。実機側の既存のpublisher配信は一度だけに保つ。

| 画面 | キャプチャ |
|---|---|
| スキャン | [scanner.png](scanner.png) |
| 設定 | [settings.png](settings.png) |
| 注意警告 | [caution.png](caution.png) |
| 危険警告 | [danger.png](danger.png) |
| スキャン後の履歴 | [history.png](history.png) |
| 復旧直後のカメラ許可未設定 | [scanner-camera-unavailable.png](scanner-camera-unavailable.png) |

## 範囲と残作業

撮影・ライト・実機カメラの許可、キャンセル時の実通信、長時間動作、配布署名の確認を示すものではない。タイトル取得の通信タイミングはIssue #2、設定のプライバシー文言はIssue #1で修正する。警告本文に既存の文字列 `\n` がそのまま表示される点や他のリリース前UI確認はIssue #8に記録する。

Xcodeの環境不整合で旧状態を起動できなかったため、同一環境の変更前画像は取得していない。ファイルはGitに保存し、PRからはこの画像が存在するコミット固定のGitHub URLを参照する。
