# 開発時の参照情報

SafeQRはiOS/iPadOS18.5以降、UIKit、Swift5言語モードのQRリーダー。純正フレームワークだけを使う。起動画面にStoryboardがあり、各機能画面はコードで構築する。

画面はScannerViewModelのCombine状態を購読する。DIContainerは通常のresolveでfactoryから生成し、resolveSingletonや明示登録の共有インスタンスは保持する。DI解決の反復は短いsmokeテストとして扱い、解放は対象を弱参照で別途確認する。現在の評価経路はEnhancedUrlRiskEvaluator→SafeBrowsingAPIClient。旧ReputationClientモックを製品の外部判定に使わない。

- ローカル判定は0–1=safe、2–3=caution、4以上=danger。入力不正は設定に関係なくdanger。詳細とテストはdocs/safety-design.mdを参照。
- 外部チェックは既定OFF。ON時の送信はv5の4byte hash prefix。失敗・未知・未照会をsafeの確認へ変換しない。
- 完全評価が終わるまでURLを開かず、注意・危険・外部未確認では確認が必要。拒否時も履歴を保存するが、タイトル取得を始めない。
- 履歴再訪も同じ確認を通す。タイトル取得は開封許可後、元URLだけに行う。
- 任意文字列のログは禁止。AppLogの定義済みイベント・数値コード・処理時間だけを使用する。
- APIキーはConfigのGit管理外ファイルへ設定。値をログやPRへ出さない。

`make tools`、`make check`でローカル/CI共通の固定版ツール・ビルド・テストを実行する。UI変更では実画面キャプチャをGit保存し、PRはコミット固定リンクにする。

最新の確認範囲と未確認条件はdocs/release-validation.md、残作業はdocs/tasks.mdに記録する。Simulatorと実機、単体テストと長時間運用、署名なしビルドと配布成功を区別する。
