# Issue #8の画面記録

2026-10-15、Xcode26.6。検証用の`.invalid` URLを使用。Simulatorのカメラ画面はDebugのモックであり、実機カメラの確認やApp Storeへ提出した画像ではない。PNG原本を加工せずGitへ保存する。

Googleの説明がある設定は、レビュー指摘を反映した最新キャプチャへ更新した。Google脅威の警告は本番API未接続のため、この操作画像には含まない。出典・精度案内・説明リンク・URL非混入は単体テストで確認する。

| ファイル | 状態 | 端末 / OS | 表示サイズ |
|---|---|---|---|
| [ipad-caution-warning.png](ipad-caution-warning.png) | 注意警告 | iPad Pro 13-inch (M4) Simulator / iPadOS26.5 (23F77) | 2064×2752 |
| [ipad-danger-warning.png](ipad-danger-warning.png) | 危険警告 | iPad Pro 13-inch (M4) Simulator / iPadOS26.5 (23F77) | 2064×2752 |
| [ipad-history-after-mock-scans.png](ipad-history-after-mock-scans.png) | スキャン履歴 | iPad Pro 13-inch (M4) Simulator / iPadOS26.5 (23F77) | 2064×2752 |
| [ipad-history-delete-confirmation.png](ipad-history-delete-confirmation.png) | 履歴全削除の確認 | iPad Pro 13-inch (M4) Simulator / iPadOS26.5 (23F77) | 2064×2752 |
| [ipad-history-empty-after-deletion.png](ipad-history-empty-after-deletion.png) | 削除後の空履歴 | iPad Pro 13-inch (M4) Simulator / iPadOS26.5 (23F77) | 2064×2752 |
| [ipad-history-revisit-warning.png](ipad-history-revisit-warning.png) | 履歴再訪の警告 | iPad Pro 13-inch (M4) Simulator / iPadOS26.5 (23F77) | 2064×2752 |
| [ipad-landscape-details.png](ipad-landscape-details.png) | 横画面の警告詳細 | iPad Pro 13-inch (M4) Simulator / iPadOS26.5 (23F77) | 2752×2064 |
| [ipad-portrait-details.png](ipad-portrait-details.png) | 縦画面の警告詳細 | iPad Pro 13-inch (M4) Simulator / iPadOS26.5 (23F77) | 2064×2752 |
| [ipad-scanner.png](ipad-scanner.png) | Debugの模擬スキャン画面 | iPad Pro 13-inch (M4) Simulator / iPadOS26.5 (23F77) | 2064×2752 |
| [ipad-settings.png](ipad-settings.png) | 設定・厳しさ標準・外部OFF | iPad Pro 13-inch (M4) Simulator / iPadOS26.5 (23F77) | 2064×2752 |
| [ipad-unverified-external-warning.png](ipad-unverified-external-warning.png) | 外部未確認の警告 | iPad Pro 13-inch (M4) Simulator / iPadOS26.5 (23F77) | 2064×2752 |
| [iphone-camera-denied.png](iphone-camera-denied.png) | カメラ拒否後の案内 | iPhone 16 Pro Simulator / iOS 26.5 (23F77) | 1206×2622 |
| [iphone-caution-warning.png](iphone-caution-warning.png) | 注意警告 | iPhone16Pro Simulator / iOS26.5 (23F77) | 1206×2622 |
| [iphone-danger-warning.png](iphone-danger-warning.png) | 危険警告 | iPhone16Pro Simulator / iOS26.5 (23F77) | 1206×2622 |
| [iphone-history-after-mock-scans.png](iphone-history-after-mock-scans.png) | スキャン履歴 | iPhone16Pro Simulator / iOS26.5 (23F77) | 1206×2622 |
| [iphone-history-delete-confirmation.png](iphone-history-delete-confirmation.png) | 履歴全削除の確認 | iPhone16Pro Simulator / iOS26.5 (23F77) | 1206×2622 |
| [iphone-history-empty-after-deletion.png](iphone-history-empty-after-deletion.png) | 削除後の空履歴 | iPhone16Pro Simulator / iOS26.5 (23F77) | 1206×2622 |
| [iphone-history-revisit-warning.png](iphone-history-revisit-warning.png) | 履歴再訪の警告 | iPhone16Pro Simulator / iOS26.5 (23F77) | 1206×2622 |
| [iphone-scanner.png](iphone-scanner.png) | Debugの模擬スキャン画面 | iPhone16Pro Simulator / iOS26.5 (23F77) | 1206×2622 |
| [iphone-settings.png](iphone-settings.png) | 設定・厳しさ標準・外部OFF | iPhone16Pro Simulator / iOS26.5 (23F77) | 1206×2622 |
| [iphone-unverified-external-warning.png](iphone-unverified-external-warning.png) | 外部未確認の警告 | iPhone16Pro Simulator / iOS26.5 (23F77) | 1206×2622 |
| [iphone-warning-before.png](iphone-warning-before.png) | 修正前・危険警告・詳細未展開 | iPhone 16 Pro Simulator / iOS 26.5 (23F77) | 1206×2622 |
| [iphone-warning-details.png](iphone-warning-details.png) | 縦画面の警告詳細 | iPhone16Pro Simulator / iOS26.5 (23F77) | 1206×2622 |
| [iphone-warning-landscape.png](iphone-warning-landscape.png) | 横画面の警告詳細 | iPhone16Pro Simulator / iOS26.5 (23F77) | 2622×1206 |
| [small-iphone-landscape-details.png](small-iphone-landscape-details.png) | 横画面の警告詳細 | iPhone SE (3rd generation) Simulator / iOS18.6 (22G86) | 1334×750 |
| [small-iphone-portrait-details.png](small-iphone-portrait-details.png) | 縦画面の警告詳細 | iPhone SE (3rd generation) Simulator / iOS18.6 (22G86) | 750×1334 |
| [small-iphone-settings.png](small-iphone-settings.png) | 設定・厳しさ標準・外部OFF | iPhone SE (3rd generation) Simulator / iOS18.6 (22G86) | 750×1334 |

横画面PNGは原本のEXIF Orientation=8で回転表示する（格納ピクセルは縦と同じ）。`iphone-warning-before.png`は修正前・詳細未展開。詳細ボタンがAXに含まれなかったため、展開後と同じ状態の比較ではない。修正前の横画面は`app.screenshot()`で一部が欠けたため採用せず、修正後は`XCUIScreen.main.screenshot()`で取得した。

各ファイルの端末・状態・格納サイズ・EXIF・SHA-256は[manifest.json](manifest.json)。PR本文は画像を含む完全コミットSHAのリンクで固定し、GitHub contentsから画像データを読み戻して照合する。一時パスや期限付きCI Artifactを画像参照先に使わない。
