# 申請画像の原本撮影記録（ストア未提出）

2026-10-16。利用者は原本4枚の採用を保留し、魅力を伝えるストア画像を希望した。その後、[読み取る場面から伝える掲載画像](store-artwork-v3/README.md)6枚と掲載順を2026-10-16の回答「ok」で採用した。この文書は原本の撮影情報として保持する。既存QA原本を、Appleの[画像仕様](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)と照合した。形式・寸法が合うことだけで、App Reviewの承認や提出準備の完了とは扱わない。

## iPhoneの候補

iPhone16Pro Simulator / iOS26.5の実装画面。検証用の模擬履歴を使っており、実際の利用履歴・実カメラ撮影ではない。カメラの模擬ボタンが写るスキャン画面は候補へ入れない。画像は加工せず既存原本を参照する。

| 順序案 | 画面 | 原本 | 寸法 / PNG | SHA256 |
|---|---|---|---|---|
| 1 | 履歴 | [模擬履歴](pr-captures/issue-8/iphone-history-after-mock-scans.png) | 1206×2622、RGB、alphaなし | e6a78f9a9c5e7002849f1d1832925e1e7309ad9466fdf60dfc1b5cacd1341865 |
| 2 | 設定 | [標準・外部OFF](pr-captures/issue-8/iphone-settings.png) | 1206×2622、RGB、alphaなし | ec575e86ae79373cd488e6d5062b952a7d0e2d5e13913b19399ad0f0ad358781 |

原本を含むコミットは `424ced83175dd6d2218e68b9947068f8f90885d5`。撮影日と状態は[画面記録](pr-captures/issue-8/README.md)を参照する。PNGヘッダーの幅・高さ・color type=2、ファイルのSHA256を読み戻して照合し、目視で個人情報・認証値がないことを確認した。Appleが求めるiPhone Dynamic Island mediumの許容寸法に一致する。

## iPadの候補

2026-10-16、専用iPad Pro 13-inch (M4) Simulator / iPadOS26.5 (23F77)でRelease版を撮影した。ビルドしたリビジョンは `fd89997defc4826deed99a75a0ef2d579a9dddd8`。アプリコードは最新main `b3c7b9f5afbff22df93c85bcdf88a99f9ee37f16` と同一で、差分が文書のみであることを確認した。APIキーは空に上書きし、外部チェックはOFF。実機カメラを撮影した画像ではない。

カメラ拒否時の設定・履歴という実装どおりの経路を使ったため、Simulatorのテストボタンや説明は写っていない。履歴は以前のテストで保存した `.invalid` URLの模擬データ3件をそのまま表示したもので、実利用履歴ではない。画面の合成やカメラの代替画像は使っていない。

| 順序案 | 画面 | 原本 | 寸法 / 形式 | SHA256 |
|---|---|---|---|---|
| 1 | 設定・標準/外部OFF | [原本](app-store-candidates/ipad-settings-camera-denied.jpg) | 2064×2752、JPEG、alphaなし | e237c3460042d466fe293941d83fb23b0f9d21a0eacd59678c0c56098bfc7b99 |
| 2 | 既存の模擬履歴3件 | [原本](app-store-candidates/ipad-history-camera-denied.jpg) | 2064×2752、JPEG、alphaなし | 17f00df89dee11605fe8504bd66831bf4a96ea144f267da1a9db1cb2e5a24f9a |

`simctl io screenshot --type=jpeg`で実画面から直接取得したJPEG原本。PNG出力にはalpha channelがあったため、提出候補へ採用せず検証用に分離した。JPEGの寸法・alphaなし・SHA256・目視確認を完了した。撮影後は専用iPadのcameraをgrantへ戻し、起動前と同じShutdown状態へ戻した。通常の実機と専用iPhoneの状態は変更していない。

構造化した撮影情報は[manifest.json](app-store-candidates/manifest.json)。以前のiPad QA画像は背後にテストUIが写るため、引き続き提出候補に含めない。原本4枚をそのまま載せる案は未採用で、撮影記録として保存する。採用した構成はv3の各3枚であり、App Store Connectにはアップロードしていない。

## 現在の採用と公開前の確認

- iPhone2枚・iPad2枚は許容寸法・alphaなし・撮影状態・ハッシュを確認済み。掲載用にはv3の6枚を利用者確認済み。
- 掲載順と画像内コピーは利用者確認済み。申請文全体の最終確認とは区別する。模擬履歴・生成使用イメージを実利用履歴・実機カメラ撮影として扱わない。
- 公開Gitの完全SHA固定URLがHTTP200で開けることを確認する。期限付きCI Artifactを永続リンクに使わない。
- App Store Connectへのアップロード、公開、審査提出は別の段階で行う。現時点では実施していない。
