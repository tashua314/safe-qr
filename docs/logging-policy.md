# アプリの診断ログ

Issue #5。Debug/Releaseとも、アプリ独自のログには定義済みのイベント名、数値のエラーコード、処理時間（整数ミリ秒）だけを残す。URL・host・path・query・fragment、タイトル、警告詳細、レスポンス本文、APIキー、NSErrorの説明・userInfoを含めない。URLをハッシュ化してログに残すこともしない。

`AppLog`は任意の文字列やErrorを引数に取らない。OSLogのsubsystemは`jp.techguide.SafeQR`、categoryは`diagnostics`。診断イベントはクラッシュ・通信・保存等の失敗を特定するために使用し、送信型の解析サービスは追加しない。OSやSafari等のシステムログをアプリがすべて制御できるという意味ではない。

`check-log-policy.py`を品質チェックで実行し、製品コードのprint/NSLog等とAppLog以外のLogger生成を拒否する。回帰検証はダミーのpath/query/fragment/titleと、それらを含むNSErrorを実際に処理し、単体テストログおよびアプリ独自OSLogにダミー値が含まれないことを確認する。エラーの数値コードと処理時間が観測できることも確認し、ログ取得失敗・0件は確認済みとして扱わない。
