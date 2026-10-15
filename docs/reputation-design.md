# Issue #1: URL全文を送らない外部照会

Google Safe Browsing v5 hashes.searchへ移行する。端末でURL正規化、Public Suffix Listによるhost suffix、path prefixの組合せ（最大30件）を生成し、各SHA-256の先頭4バイトをbase64で送信する。scheme、認証情報、port、URL全文、完全ハッシュは送信しない。応答の完全ハッシュと端末の候補を比較し、prefix衝突を脅威に変換しない。

URL正規化はGoogle仕様に従い、改行/tab削除、元fragment削除、繰返しpercent decode、IDN/Punycode、IPv4のhex/octal/短縮表記、IPv6圧縮/IPv4 mapped/NAT64、hostドット、pathドットと連続slash、byte escapingを扱う。queryはpath正規化しない。Public Suffix Listは公式配布のsnapshotをアプリ同梱し、wildcard/exception/private rulesを使用する。リソース読み込み失敗は照会失敗にする。

HTTP自動キャッシュとCookieを無効にし、応答のcacheDurationに従うメモリ内キャッシュだけを使う。V4時代のUserDefaultsキャッシュを参照しない。外部チェックOFFはネットワーク要求を発生させない。レスポンス厳密検証と一括照会の失敗保持はIssue #6で実装済み。完全ハッシュ長、TTLのprotobuf上限・オーバーフローも検証し、不正応答を保存しない。

画面とREADME、プライバシー、Store申請資料の送信説明を合わせる。ハッシュprefixから候補が推測される可能性、GoogleへのIP等のネットワーク情報送信、タイトル取得/ブラウザ表示は対象サイトへの通信となる点を説明する。

URLProtocolテストでraw URLやmarkerがrequestにないこと、4byte prefix、OFF無通信、prefix衝突、正規化公式例、PSL境界、TTLを確認する。iOS Debug/Releaseビルド、lint、既存テストとUI表示を確認する。実際のAPI認証はIssue #4で実キーが利用できる場合に検証し、未確認を成功と扱わない。

参照:
- https://developers.google.com/safe-browsing/reference/URLs.and.Hashing
- https://developers.google.com/safe-browsing/reference/rest/v5/hashes/search
- https://publicsuffix.org/list/

## Issue #6:照会状態

単独・一括ともURLごとのResultを保持する。OFFはdisabled、キー未設定・HTTP/ネットワーク・不正応答はfailure。noMatchは有効な200応答に限る。未知type/attributeのdetailは適用せずunrecognizedThreatsとし、既知の脅威は保持する。未知情報しかない場合safetyLevelはnilで、無害性の確認ではない。Enhanced評価はlocalFallbackとして区別する。

protobuf JSONで空fullHashesが省略された形は有効、null/誤った型/脅威詳細欠落はfailureとする。不正応答やfailureはcacheへ保存しない。未知の値を含む有効な応答はその情報のままTTL付きcacheへ保持し、cache hitでも未知状態を失わない。

Googleの[利用条件](https://developers.google.com/safe-browsing/terms)に合わせ、fullHashを含むprefixのキャッシュはサーバーTTLと30分の短い方まで。陰性prefixはサーバーTTLを維持する。利用開始前の設定とGoogle検出の警告には、出典リンクと精度・信頼性の限界、誤判定・見逃しの可能性を表示する。ローカル警告にGoogleの危険判定の出典を付けない。

## 配布方針と将来の収益化

2026-10-15の利用者の提案に基づき、当面は収益化せず、Safe Browsingを任意の外部チェックに使う方針とする。非商用条件は現在の売上が0というだけで判定せず、販売・広告・課金等の収益獲得を目的とする使い方を避け、実際の用途を公開前に確認する。

収益化は、Web Risk APIへの移行・検証を完了してから開始する。移行時は認証、料金・クォータ、応答/キャッシュ、警告の出典、通信内容とプライバシー案内を確認する。移行完了までは収益化を始めない。

Web RiskのLookup APIはURL全文を送るため、現在の「GoogleへURL全文を送らない」という契約を維持する候補はUpdate APIである。ローカルの脅威リストの更新・照合が必要で、APIキーだけの変更では完了しない。方式・費用を評価してから別途実装する。現時点ではWeb Risk移行は未実装。

一次資料：[Safe Browsingの用途条件](https://developers.google.com/safe-browsing/reference/Appropriate.Usage)、[Web Riskの方式比較](https://docs.cloud.google.com/web-risk/docs/overview)、[料金](https://cloud.google.com/web-risk/pricing)。
