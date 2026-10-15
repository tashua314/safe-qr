# App Storeの年齢・プライバシー回答案

2026-10-15。対象実装は`aa99934084b55770ab4b92e16ab3a9b90b2f03f4`。未入力・未提出の下書き。回答案を最終レーティングや「データ収集なし」の確定へ読み替えない。コードや外部サービスの扱いが変わった場合は見直す。

## 年齢質問の回答案

Appleはアプリ内の自由なWeb閲覧をUnrestricted Web Accessとし、OS26以降の16+、それより前の17+の説明に含める。最終値は実際の回答・OS・配布地域・EULA等に応じて確認する。[Appleの年齢定義](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/)、[設定手順](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/)

| 項目 | 現実装からの回答案・根拠 |
|---|---|
| Unrestricted Web Access | あり。任意QRのHTTP(S) URLをSFSafariViewControllerで開く。ドメインの許可リストや年齢制限はない。警告での開封確認は、この機能がないという回答の根拠にならない |
| Parental Controls / Age Assurance | なし。検出強度の設定は利用者自身が変更でき、保護者向けのアクセス管理や年齢確認を行わない |
| User-Generated Content / Social Media | 自前の配信機能はなし。履歴は端末内のみで、公開投稿・フィード・利用者間共有の機能はない。一般Web閲覧の能力は別項で申告する |
| Messaging and Chat / Advertising | 自前のチャット・広告配信はなし。外部Webページの機能とアプリ自身の機能を区別して実際の質問に回答する |
| 粗野な言葉・恐怖、医療/健康、暴力/武器、性的表現、飲酒/喫煙/薬物、賭博、コンテスト、loot box | 自前の収録コンテンツ・ゲーム機能はなし。任意リンク先の内容を一律に安全・全年齢向けと保証する回答にはしない |
| Kids、年齢上書き、EULAの最低年齢 | Apple標準EULAを使う申請方針は利用者確認済み。Kids・年齢上書きや最低年齢は、計算結果と各項目の条件を確認してから決める。現時点で4+やKids向けを設定しない |

根拠：[URL開封処理](https://github.com/tashua314/safe-qr/blob/aa99934084b55770ab4b92e16ab3a9b90b2f03f4/SafeQR/SafeQR/Presentation/ScannerViewController.swift)、[利用者設定](https://github.com/tashua314/safe-qr/blob/aa99934084b55770ab4b92e16ab3a9b90b2f03f4/SafeQR/SafeQR/Services/Settings/SettingsStore.swift)。上表は実装に基づく回答案であり、Appleによる審査・算定結果ではない。

## App Privacyの確認案

Appleの収集の定義は、端末外で要求処理に必要な期間を超えて参照可能になるかが要点。端末内完結、一般Web閲覧、組み込んだ安全性照会を分ける。任意ONだけで申告を省かない。[App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)

| 処理 | 確認できる実装・回答を確定する際の扱い |
|---|---|
| カメラ映像 | QR読取に使用し、画像/動画の保存やアップロードは実装していない。利用許可が必要なことと、端末外収集の申告は別 |
| 履歴・設定 | URL、取得タイトル等の履歴はCore Data、設定はUserDefaultsに端末内保存。開発者サーバーへの履歴送信はない。外部通信で派生情報を送る処理は次項で別に確認する |
| Google安全性照会 | 任意ON時にURL候補のSHA-256先頭4byteを送信。GoogleにはIP等の通信情報も届く。外部事業者側の保持・用途・紐付けを確認するまで「データ収集なし」を確定しない。ハッシュは完全匿名の根拠にならない |
| タイトル取得 | 元URLへURLSessionで要求し、HTTPリダイレクトは追わない。注意/危険/外部未確認では開封許可後に開始する。下記のWeb閲覧の例外を、この要求へ自動的に適用しない |
| ブラウザー表示 | SFSafariViewControllerで任意のWebを開く。Appleのopen webに関する扱いを確認し、組み込んだGoogle照会と混同しない |
| トラッキング | 自社コードに広告識別子取得、広告向けの結合、独自分析送信はない。最終回答は第三者の実際の処理も照合する。通信やIPの存在だけで自動的にトラッキングと判定しない |

[Google照会コード](https://github.com/tashua314/safe-qr/blob/aa99934084b55770ab4b92e16ab3a9b90b2f03f4/SafeQR/SafeQR/Data/Reputation/SafeBrowsingAPIClient.swift)、[タイトル取得コード](https://github.com/tashua314/safe-qr/blob/aa99934084b55770ab4b92e16ab3a9b90b2f03f4/SafeQR/SafeQR/Data/Metadata/HtmlTitleFetcher.swift)、[プライバシー下書き](privacy-policy-draft.md)を根拠に、必要なデータ種別・用途・利用者との紐付け・トラッキングを決める。Google APIキーはアプリの認証情報、Bundle IDはアプリ共通値であり、それだけで利用者IDや端末IDと同一視しない。実キーや端末IDを申請文へ貼らない。

UserDefaultsの必須理由API宣言はIssue #31 / PR #32で対応済み。理由宣言はApp Privacy回答の確定を代替しない。

## 最終確定に必要な入力

運営者TechGuide合同会社・公開窓口[問い合わせフォーム](https://techguide.jp/contact/?category=other&subject=SafeQR)は利用者確認済み。[サポート](https://techguide.jp/safeqr/)と[プライバシーポリシー](https://techguide.jp/safeqr/privacy/)の公開・HTTP200は2026-10-16確認済み。無料・日本のみ・Apple標準EULAの申請方針は2026-10-16利用者確認済み。当面は無料アプリ単独で提供し、会社の集客・有償サービスへの誘導・顧客向けサービスには使う予定がないと利用者が追加確認した。既存の広告・課金等による収益化をしない方針と合わせ、販売・収益目的でないという[Google公式条件](https://developers.google.com/safe-browsing/reference/Appropriate.Usage)に沿うと判断する（2026-10-16照合）。これは確認済みの用途に基づく判断でGoogleの個別承認ではない。会社名義や無料という一点だけで判断せず、用途変更前には再確認し、収益化開始前にWeb Riskへ移行する。年齢の最終回答と外部事業者の保持・紐付けの確認は引き続き残す。掲載画像6枚・画像内コピー・順序は利用者確認済み。申請文全体は最終確認前。App Store Connectでの回答保存・公開・アップロード・審査提出は実施していない。
