# ビルド・権限・品質チェック

最低対応OSはiOS 18.5。UIKitで画面を構築し、AVFoundation / SafariServices / CoreDataを使用する。
Info.plistのカメラ利用説明は「QRコード読み取りのためにカメラを使用します。」。

## セットアップ

Xcodeと、対応するiOS Simulatorをインストールする。Xcode更新後に共有Developerフレームワークの不整合や「platform is not installed」が出た場合は、次の順に確認する。

```sh
xcodebuild -runFirstLaunch
xcodebuild -list -project SafeQR/SafeQR.xcodeproj
xcodebuild -downloadPlatform iOS -architectureVariant arm64
xcrun simctl list devices available
make tools
```

Intel MacではSimulator取得時の `-architectureVariant arm64` を省略する。
Xcodeの初回セットアップはOS側の開発コンポーネントを更新する。プロジェクトの読み込み成功とアプリのビルド成功はそれぞれ確認する。

## チェックツールの固定

SwiftLint 0.63.2 / SwiftFormat 0.61.1をローカルとCIで使用する。`make tools` は各公式GitHub Releaseのアーカイブを取得し、`scripts/tool-config.sh` のSHA-256を照合してから `.artifacts/tools/` へ展開する。システムのHomebrewや他プロジェクトのツールは変更しない。既存PATHのツールが同じバージョンであればそれも使用できるが、違う場合はチェックを失敗させる。

CIで自動取得した最新版とローカル版の整形ルールが異なる問題を再現したため、検証した組合せを固定した。更新時はバージョン・公式アーカイブのdigestを変更し、整形差分と全チェックをまとめて検証する。

## 品質チェック

```sh
make check
```

`mac-clipy` の構成を参考に、次の確認を一つのコマンドにまとめた。

- SwiftLintのstrictモード（キャッシュを使わない）。
- SwiftFormatの整形差分チェック。書き換えは `make format` で行う。
- project.pbxproj / Info.plistの構文検査。
- Swift警告をエラーとするDebug / ReleaseのSimulatorビルド。
- iOS 18.5以上の検証専用 `SafeQR QA iPhone` SimulatorでユニットテストとUIテスト。既存があれば再利用し、なければ作成する。

ツールがない場合は失敗する。ビルド・テストのログと `.xcresult` は `.artifacts/` に保存し、Gitに含めない。
GitHub ActionsではPRとmainへのpushで同じスクリプトを実行し、結果をArtifactに保存する。

チェック時は専用Simulatorへアプリをインストールし、そのSimulator内でSafeQRのカメラ許可を付与する。通常スイート後にcameraをrevokeして拒否状態のUIテストを個別実行し、成功/失敗時ともtrapでgrantへ戻す。通常スイート内ではこの1件を意図的にskipし、個別実行で検証する。実機の権限は変更しない。別の検証専用デバイスを使う場合はUUIDを指定する。

```sh
SAFEQR_SIMULATOR_ID=<検証専用デバイスのUUID> make check
```

## lintの方針

Swift 5のコードに合わせて整形設定を調整した。強制キャスト・`try!`・強制アンラップ・暗黙のアンラップはエラーとする。
UIKitの画面セルは個別ファイルへ分離し、警告ダイアログのprivateな状態は一つのファイルに保つため、ファイル長の警告は600行、エラーは650行とする。
定数の名前空間や評価結果の状態型は3階層まで許可する。`QR` / `UI` / `ID` は意味の明確な略語として扱う。

## 検証の範囲

Simulatorの成功は、実機カメラ・ライト・バッテリー・配布署名・App Store申請の確認を意味しない。
これらの実機・配布確認はリリース準備の記録で別途扱う。
APIキーは `.xcconfig` で注入し、値をGit・CIログ・検証記録へ出さない。設定方法は `SafeQR/Config/README.md` を参照する。

## Core Dataのテスト

履歴テストはアプリと同じNSManagedObjectModelインスタンスを参照し、各テストのstoreは独立したin-memory構成にする。modelを毎回再読込して同一entity classへ重複登録すると曖昧性警告が出るため、modelとstoreの独立性を分ける。2026-10-15に履歴15件を再実行し成功、model重複・unique match警告が出ないことを確認した。
