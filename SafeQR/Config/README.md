# 環境変数セットアップガイド

SafeQRアプリの環境変数（APIキーなど）を設定するための手順書です。

## 概要

このプロジェクトでは、開発環境と本番環境で異なる設定を使用するために、Xcodeの Configuration Files (.xcconfig) を使用しています。

## ファイル構成

```
Config/
├── Debug.xcconfig              # デバッグ環境設定（APIキーのプレースホルダー）
├── Release.xcconfig            # リリース環境設定（APIキーのプレースホルダー）
├── Local.xcconfig              # ローカル開発環境設定（APIキーのプレースホルダー）
├── Production.xcconfig         # 本番環境設定（APIキーのプレースホルダー）
├── Local-Keys.xcconfig.template    # ローカル開発用APIキーテンプレート
├── Production-Keys.xcconfig.template # 本番環境用APIキーテンプレート
└── README.md                   # このファイル
```

## セットアップ手順

### 1. テンプレートファイルをコピー

```bash
# ローカル開発用
cp Config/Local-Keys.xcconfig.template Config/Local-Keys.xcconfig

# 本番環境用
cp Config/Production-Keys.xcconfig.template Config/Production-Keys.xcconfig
```

### 2. APIキーを設定

各ファイルを編集して、`YOUR_DEV_API_KEY_HERE` および `YOUR_PROD_API_KEY_HERE` を実際のAPIキーに置き換えます。

#### Google Safe Browsing API キーの取得方法

1. [Google Cloud Console](https://console.cloud.google.com/) にアクセス
2. プロジェクトを作成または選択
3. Google Safe Browsing API を有効化
4. 「認証情報」でAPIキーを作成
5. APIキーを制限（Safe Browsing API のみに制限することを推奨）

### 3. Xcodeプロジェクトに設定ファイルを追加

1. Xcodeでプロジェクトを開く
2. プロジェクトナビゲーターで「Config」グループを作成
3. `Local-Keys.xcconfig` と `Production-Keys.xcconfig` をプロジェクトに追加
4. プロジェクト設定を開く
5. 「Info」タブの「Configurations」で各ビルド設定に対応するファイルを指定：
   - **Debug** → `Local-Keys.xcconfig`
   - **Release** → `Production-Keys.xcconfig`

### 4. ビルド設定の確認

プロジェクト設定の「Build Settings」で以下の値が正しく設定されていることを確認：

- `SAFE_BROWSING_API_KEY`: `$(SAFE_BROWSING_API_KEY)`
- `PRODUCT_BUNDLE_IDENTIFIER`: 
  - Debug: `jp.techguide.SafeQR.dev`
  - Release: `jp.techguide.SafeQR`

## 使用方法

設定完了後、アプリ内で以下のように環境変数にアクセスできます：

```swift
// Info.plistから APIキーを取得
if let apiKey = Bundle.main.object(forInfoDictionaryKey: "SafeBrowsingAPIKey") as? String {
    print("API Key: \\(apiKey)")
}
```

## セキュリティ注意事項

1. **APIキーファイルをGitにコミットしない**
   - `Local-Keys.xcconfig` と `Production-Keys.xcconfig` は `.gitignore` に含まれています
   - テンプレートファイル（`.template` 拡張子）のみがリポジトリに含まれます

2. **APIキーの制限**
   - Google Cloud Console でAPIキーを適切に制限してください
   - 不要なサービスへのアクセスを制限することでセキュリティリスクを軽減します

3. **チーム開発での共有**
   - APIキーは安全な方法（暗号化された共有ツールなど）で チームメンバーと共有してください
   - Slack やメールでの平文送信は避けてください

## トラブルシューティング

### APIキーが反映されない場合

1. Xcodeプロジェクト設定で正しい `.xcconfig` ファイルが指定されているか確認
2. プロジェクトをクリーンビルドしてみる（⌘+Shift+K）
3. `$(SAFE_BROWSING_API_KEY)` が Info.plist に正しく設定されているか確認

### ビルドエラーが発生する場合

1. `.xcconfig` ファイルのシンタックスエラーがないか確認
2. ファイルがXcodeプロジェクトに正しく追加されているか確認
3. Derived Data をクリアしてみる

## 環境別の動作確認

### Debug ビルドの確認
```bash
# デバッグビルドを実行し、コンソールでAPIキーが正しく読み込まれているか確認
# ログに "Safe Browsing APIキーが設定されていません" が表示されないことを確認
```

### Release ビルドの確認
```bash
# リリースビルドでも同様に確認
# 本番用APIキーが正しく使用されていることを確認
```

このセットアップにより、開発環境と本番環境で適切に異なる設定を使用できるようになります。