# 必須理由APIの宣言

2026-10-15。`SafeQR/SafeQR/PrivacyInfo.xcprivacy`は、`SettingsStore`が自アプリの検出強度と外部チェック設定を保存・参照するため、`NSPrivacyAccessedAPICategoryUserDefaults`の理由`CA92.1`を宣言する。App GroupやMDM・他アプリの設定を読む用途はない。

Appleは必須理由APIの用途をマニフェストへ記載するよう求めており、UserDefaultsを対象としている。[必須理由APIの説明](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)、[UserDefaultsと理由の定義](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons)

Xcodeの同期グループでアプリのリソースへ含める。`scripts/check.sh`はDebug/Releaseビルド後、それぞれの`.app/PrivacyInfo.xcprivacy`が存在し、plistとして読めること、およびUserDefaults / CA92.1の宣言値があることを検査する。必須宣言の欠落・誤った理由値・型の不正・ファイル欠落が失敗になることもportableテストで確認する。ソースファイルの存在だけを同梱確認へ読み替えない。

このファイルは必須理由APIの宣言を扱う。App Store Connectのデータ収集・トラッキング回答や、プライバシーポリシーの最終確定とは別であり、「データ収集なし」を宣言するものではない。外部チェック時のGoogleへの通信などは[プライバシー下書き](privacy-policy-draft.md)と実際の第三者処理を確認して回答する。アップロード・審査提出は実施していない。
