# Issue #2の確認画面

2026-10-15、Xcode26.6、iOS26.5、専用iPhone16Pro Simulator、Debug、縦1206×2622、ダークモード。成功した`SafeQRUITests/testSettingsHistoryAndMockScanWarnings()`の添付画像をそのまま保存した。

- `caution.png`：標準/外部OFFで注意URLをスキャンし、まだ開封を選んでいない。
- `danger.png`：同条件で危険URLをスキャンし、まだ開封を選んでいない。
- `history-revisit.png`：拒否後の履歴をタップし、危険判定の確認を再表示した。
- `unverified.png`：外部ON/キー未設定でローカルsafeのURLをスキャンし、安全性未確認として開封確認を表示した。

警告を拒否するとタイトル取得を開始しない。描画・文字・操作結果を確認済み。実カメラ画像ではなく、Simulator用の`.invalid`テストURLを使用する。変更前の警告は`../issue-7/caution.png`と`danger.png`に保存されている。

テスト結果は単体84件、Swift Testing1件、UI6件成功。管理下のHTTP302テストで元URL1要求・リダイレクト先0要求を確認した。実機・本番認証はリリース前確認で管理する。
