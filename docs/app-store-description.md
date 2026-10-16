# App Store申請文（下書き）

2026-10-16更新。運営者はTechGuide合同会社、公開窓口は[問い合わせフォーム](https://techguide.jp/contact/?category=other&subject=SafeQR)。[サポート](https://techguide.jp/safeqr/)・[プライバシー](https://techguide.jp/safeqr/privacy/)は公開確認済み。実機の基本動作・本番API・開発用署名/exportは確認済み。初回カメラ拒否は別Bundle IDで確認済み、10分待機記録も完了。負荷テストは利用者判断で省略。申請方針は無料・日本のみ・Apple標準EULAと利用者確認済み。修正後実機CPUと一部の申請条件は未確認/未確定のため未提出。構造化した項目はapp-store-metadata.jsonを参照。

## 日本語

「このQRコード、開いて大丈夫かな？」と思ったら。
SafeQRは、リンクに気になる点が見つかると、開く前に注意をお知らせするQRコードリーダーです。

1. QRコードにカメラをかざす
アプリを開いて、読み取りたいQRコードにカメラを向けるだけ。リンクの注意点を端末内でチェックします。

2. 注意が出たら、開かずに戻れる
注意や危険の可能性が表示されたら、内容を確認して開くのをやめられます。迷ったときに、いったん立ち止まれます。

3. 読み取ったリンクを、あとから見返す
履歴は端末内に最大50件保存。読み取った回数や最新の判定を確認でき、不要な履歴は1件ずつでも、まとめてでも削除できます。履歴からリンクを開くときも、あらためてチェックします。

チェックの厳しさは「弱・標準・強」から選べます。注意がないと判定されたリンクは、確認画面を挟まずに開きます。外部チェックをONにしていてチェックが完了しなかった場合は、開く前に確認画面が出ます。

判定は安全性を保証しません。危険なサイトの見逃しや、安全なサイトへの誤警告が起こる可能性があります。リンク先や入力情報を確認してください。

通信とプライバシー
外部チェックは既定OFFです。ONにすると、Google Safe BrowsingへURL候補のSHA-256先頭4バイトを送り、端末内で完全ハッシュを比較します。URL全文はGoogleへ送りませんが、IP等の通信情報が届き、ハッシュの一部から候補が推測される可能性があります。

タイトル取得とブラウザー表示は対象サイトへ通信します。注意・危険・外部未確認では開封を許可するまで開始しません。取得できたタイトルは端末内の履歴へ保存します。

iOS/iPadOS18.5以降に対応。現在のアプリ画面は日本語です。

## English

Unsure whether to open a QR-code link?
SafeQR is a QR-code reader that alerts you before opening a link when it finds something to watch out for.

1. Point your camera at a QR code
Open the app and point your camera at the code you want to scan. SafeQR checks the link for potential risks on your device.

2. If a warning appears, you can go back without opening
When a caution or possible danger is shown, you can read the warning and cancel. Take a moment to pause when you are unsure.

3. Find scanned links again
Keep up to 50 history records on your device. See scan counts and the latest risk result, and delete records individually or all at once. Links opened from history are checked again.

Choose low, standard, or high strictness. Links assessed as having no concerns open without a confirmation screen. If external checks are enabled but cannot be completed, a confirmation screen appears before opening.

Risk checks do not guarantee safety. Risky sites may be missed and harmless sites may be flagged. Check the destination and the information you enter.

Network use
External checks are off by default. When enabled, SafeQR sends 4-byte SHA-256 prefixes of URL candidates to Google Safe Browsing and compares full hashes on your device. The raw URL is not sent to Google, but network information such as your IP address is visible and prefixes may allow candidates to be inferred.

Title retrieval and browsing contact the destination website. They start only after you allow opening when a warning or an unverified result is shown. Retrieved titles are stored with local history.

Requires iOS/iPadOS18.5 or later. The app interface is currently in Japanese.

## 審査メモ

申請前の下書き。カメラ画像・動画は保存せず、QRのURLを評価する。外部チェックは既定OFF。ON時はGoogle Safe Browsing v5 hashes.searchへ4byte SHA-256 prefixだけを送り、完全ハッシュは端末内照合。注意・危険・外部未確認では開封確認が必要で、許可前にタイトル取得とブラウザー表示をしない。履歴再訪も同様。タイトル取得は元URLだけでリダイレクトを追わない。判定には見逃し・誤警告があり得る。実機の基本動作、本番API認証、開発用署名/exportは確認済み。別Bundle IDの新規Releaseで初回カメラ拒否の案内・履歴/設定も確認し、通常版データは保持した。カメラ待機10分の記録は完了。CPU高値に対するレイアウト循環修正はPR #28、修正後実機CPUは未確認。利用者判断で30分連続・多数回スキャン等の負荷テストを省略した。Leaks、温度/電池、UI遅延は未確認。運営者はTechGuide合同会社、公開窓口は[問い合わせフォーム](https://techguide.jp/contact/?category=other&subject=SafeQR)と利用者確認済み。サポートURL https://techguide.jp/safeqr/ とプライバシーURL https://techguide.jp/safeqr/privacy/ の公開を確認済み。無料・日本のみ・Apple標準EULAの申請方針は利用者確認済み。当面は無料アプリ単独で提供し会社の集客・有償サービスへの誘導・顧客向けサービスには使わないと利用者確認済み。広告・課金等で収益化しない既存方針と合わせ、Googleの販売・収益目的でないという条件に照合した。Googleの個別承認ではなく用途変更前に再確認する。年齢/App Privacyの確定は未完了。審査用の氏名・電話・メールは利用者確認済みの非公開資料に分離し、公開Gitでは値をnullに保つ。App Store向け配布・アップロード・審査提出は未実施。詳細はrelease-validation.mdを参照する。
