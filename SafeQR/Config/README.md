# Safe Browsingキー設定

アプリターゲットのDebugは`Debug.xcconfig`、Releaseは`Release.xcconfig`へ接続済み。いずれも空の値を初期値にし、同じフォルダのGit管理外キーファイルを任意includeする。新しいcheckoutでもXcodeの手動接続は不要。

リポジトリのルートで実行する。

```sh
cp SafeQR/Config/Local-Keys.xcconfig.template SafeQR/Config/Local-Keys.xcconfig
cp SafeQR/Config/Production-Keys.xcconfig.template SafeQR/Config/Production-Keys.xcconfig
```

生成したファイルをローカルエディターで開き、`SAFE_BROWSING_API_KEY`に開発用・配布用の値をそれぞれ設定する。`.template`には実キーを書かない。未設定のままでもDebug/Releaseをビルドでき、照会は`apiKeyMissing`として扱う。空値、未展開変数、`YOUR_*`、不正文字を含む値は送信しない。アプリ起動時の環境変数はキー取得元にしない。

Bundle IDは既存の`jp.techguide.SafeQR`、製品名は`SafeQR`を両構成で維持する。キー設定からアプリ名や署名設定を変更しない。

```sh
make tools
make check
```

ビルド後は、生成されたアプリのInfo.plistを値の表示なしで確認できる。

```sh
python3 scripts/verify-api-key-config.py .artifacts/DerivedData/Build/Products/Debug-iphonesimulator/SafeQR.app/Info.plist
python3 scripts/verify-api-key-config.py .artifacts/DerivedData/Build/Products/Release-iphonesimulator/SafeQR.app/Info.plist
```

出力は`configured`または`missing`だけ。認証成功を意味しない。実キーをCLI引数、`-showBuildSettings`出力、ログ、Issue/PR、チャットへ貼らない。開発・CIの確認はダミー値とURLProtocolを使う。本番キーでの認証・クォータ確認は実機のリリース前確認に記録する。

Safe Browsing v5を使えるGoogle CloudプロジェクトでAPIを有効にし、用途に合ったAPI制限・クォータを設定する。アプリへ埋め込まれたキーは配布バイナリから取り出せるため、秘密として保護される前提にはしない。[Googleの利用条件](https://developers.google.com/safe-browsing/reference/Appropriate.Usage)では非商用に限定され、販売や収益を伴う用途ではWeb Riskを案内している。配布方針はIssue #8で確認する。

`Local.xcconfig`と`Production.xcconfig`は以前の手順との互換includeであり、通常は選び直す必要はない。実キーファイルは既存の`.gitignore`で除外する。
