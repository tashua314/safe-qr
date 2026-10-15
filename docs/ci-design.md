# CIの実行範囲と時間短縮（Issue #17）

## 設計

- PRではUbuntu 24.04で変更判定、シェル構文、Python回帰テスト、ログ規約、JSON構文を確認する。
- docs/配下、README.md、CLAUDE.mdだけの変更ではmacOSを省く。docs/はアプリのビルド入力に使わない。
- Swift、Xcode、CI、scripts、未知のパスはmacOSを必要とする。renameは旧/新パスを両方評価し、判定エラーでは失敗する。
- workflow全体をpaths-ignoreで省かず、最終Quality gateを常に実行する。Linuxの失敗、必要なmacOSの失敗/取消/予期しない省略を成功にしない。
- 浅いcheckoutにイベントの基準コミットがない場合、そのSHAだけを取得する。取得失敗は失敗扱いにし、mainが進んだ場合も比較対象を省略しない。
- 手動実行は変更種別に関係なく全検証する。自動実行はPRへ集約する。mainへ直接pushせず、最新mainを含むPRの検証成功後にマージする。
- 固定版SwiftLint/SwiftFormatとSHA-256を維持する。導入は改善前の実測で2〜4秒のため、大型キャッシュやLinux用ツール配布物の追加は行わない。
- mac-clipyのmake checkを入口とした一括検証、strict lint、警告をエラーにする方針を引き続き利用する。

## macOSで維持する検証

専用Simulatorの起動を先に開始する。Debugはbuild-for-testingでアプリとテストを一度だけ生成し、Release buildも行う。Simulator準備を待ってからアプリを導入し、通常とカメラ拒否をtest-without-buildingで実行する。

全単体/UIテスト、Releaseの警告検査、権限拒否の個別実行とskip 0を維持する。失敗時は自分で起動したbootstatus監視を終了し、変更した専用Simulatorのカメラ権限を復元する。実機の権限は操作しない。

## 証跡と時間

各工程と合計を.artifacts/phase-times.logへ記録し、GitHubのStep summaryにも表示する。Simulatorの準備待ちはビルド後に残った待ち時間で、起動の全所要時間とは異なる。合計と工程時間の単純な加算は一致しない場合がある。

ログ/xcresultは7日保存する。保存先を限定し、秘密設定ファイルやDerivedDataをアップロードしない。PR画面キャプチャはGitの完全コミットSHAに固定し、期限付きArtifactへ置き換えない。

## 検証計画

変更判定は文書、Swift、CI設定、未知パス、削除、アプリからdocsへのrename、不正なbase、手動強制を一時Gitリポジトリで確認する。最終ゲートは失敗/取消/不正出力/予期しない省略を拒否することを確認する。

portableチェックとactionlintの後、改善したmake checkを専用Simulatorで実行する。同じ実PRで、一時的な検証ベースに対する文書だけの差分がmacOSを省略することを先に確認する。その後mainをベースに切り替え、全macOS検証と最終HEADの独立レビュー・CI成功を確認してからマージする。検証用ベースへはマージしない。

## 必須チェックの運用

GitHubで必須チェックを設定する場合は、常に結果を返すQuality gateを選ぶ。今回、リポジトリのブランチ保護設定自体は変更しない。

## 比較基準

改善前の公開CI 38687487667（9fdbdaed74a4928fd3c72742c31e98cc9361c2d9）はmacOSジョブ12分13秒。XCTest99件、Swift Testing1件、通常UI9件が成功し、通常の拒否1件は分離後に個別成功・skip 0だった。同名の起動テストを4構成で実行するため、xcresult summaryの集約件数とは一致しない。

改善後の実測と文書のみの実行結果は、この計画の検証が完了してから追記する。単発実行や温まったローカルSimulatorから短縮率を断定しない。
