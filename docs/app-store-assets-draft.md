# 申請画像の候補（未承認・未提出）

2026-10-16。既存QA原本から候補を選び、Appleの[画像仕様](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)と照合した。形式・寸法が合うことだけで、App Reviewの承認や提出準備の完了とは扱わない。

## iPhoneの候補

iPhone16Pro Simulator / iOS26.5の実装画面。検証用の模擬履歴を使っており、実際の利用履歴・実カメラ撮影ではない。カメラの模擬ボタンが写るスキャン画面は候補へ入れない。画像は加工せず既存原本を参照する。

| 順序案 | 画面 | 原本 | 寸法 / PNG | SHA256 |
|---|---|---|---|---|
| 1 | 履歴 | [模擬履歴](pr-captures/issue-8/iphone-history-after-mock-scans.png) | 1206×2622、RGB、alphaなし | e6a78f9a9c5e7002849f1d1832925e1e7309ad9466fdf60dfc1b5cacd1341865 |
| 2 | 設定 | [標準・外部OFF](pr-captures/issue-8/iphone-settings.png) | 1206×2622、RGB、alphaなし | ec575e86ae79373cd488e6d5062b952a7d0e2d5e13913b19399ad0f0ad358781 |

原本を含むコミットは `424ced83175dd6d2218e68b9947068f8f90885d5`。撮影日と状態は[画面記録](pr-captures/issue-8/README.md)を参照する。PNGヘッダーの幅・高さ・color type=2、ファイルのSHA256を読み戻して照合し、目視で個人情報・認証値がないことを確認した。Appleが求めるiPhone Dynamic Island mediumの許容寸法に一致する。

## iPadは再取得待ち

既存のiPad画像は2064×2752で仕様に合うが、背後にSimulatorのテストボタンや説明が写っているため提出候補に採用しない。iPad対応アプリには13インチの画像が必要なため、iPhoneだけで画像準備完了とは扱わない。

次は専用iPad Simulatorで、カメラ拒否時の設定など、実装どおりの画面を取得する。実機カメラの代用品を合成せず、権限状態・表示内容を記録する。撮影は次回の専用Simulator操作時に行う。撮影と採否の確認ができるまで、メタデータのscreenshots.statusはdraftを維持する。

## 最終確定前の確認

- iPadの候補取得、PC用の加工ではない実画面・alphaなし・許容寸法・状態の確認。
- 候補画像と日本語ストア説明の対応、模擬履歴を使う説明、掲載順を利用者が確認する。
- 公開Gitの完全SHA固定URLがHTTP200で開けることを確認する。期限付きCI Artifactを永続リンクに使わない。
- App Store Connectへのアップロード、公開、審査提出は別の段階で行う。現時点では実施していない。
