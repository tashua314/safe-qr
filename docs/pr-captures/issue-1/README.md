# Issue #1 設定画面の送信説明

2026-10-15、Xcode 26.6 / iOS 26.5 / 専用iPhone 16 Pro、Debug、縦1206×2622、ダーク表示、外部チェックOFF・厳しさ標準。

- [変更前](settings-before.png)：Issue #7 / da075dfの実操作テストから抽出。URLの内容は外部へ送信されないという既存説明。
- [変更後](settings-after.png)：Issue #1 / 904affdの全テストで、設定画面を開いた際の実キャプチャ。Googleへの4byte prefix/IP情報と推測可能性、対象サイトへのタイトル・ページ通信を説明する。

本文全体とON/OFFスイッチが表示されることを実画像で確認した。画像は加工せず、Gitへ保存し、PRはこのファイルが存在するコミット固定URLを使う。

Issue #1の同じコードでSwiftLint違反0、Debug/Releaseビルド、XCTest59件（新規19件を含む）、Swift Testing1件、UI6件が成功。実APIの認証は未検証で、Issue #4で管理する。
