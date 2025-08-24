# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
SafeQR - iOS 13以降対応の安全なQRコードリーダー。ITリテラシーが低い方でも迷わず使えることを最優先設計。

## Key Requirements
- **最低対応OS**: iOS 13.0
- **UIフレームワーク**: UIKit（Storyboard無し、コードでUI構築）
- **言語**: Swift
- **依存**: 純正フレームワークのみ（AVFoundation, SafariServices, CoreData）

## Architecture Overview

### Layer Structure
```
Presentation (UIKit) → Domain (Business Logic) → Data (Storage/External)
```

### Core Components
- **QRScannerService**: AVCaptureSession/AVMetadataOutput でQRコード検出
- **UrlRiskEvaluator**: 端末内危険度スコアリング（safe/caution/danger）
- **HistoryRepository**: Core Data管理、最大50件制御、重複URL時はvisitCount加算
- **ReputationClient**: 外部レピュテーション照会（URLの生値は送信しない、ドメインハッシュのみ）
- **HtmlTitleFetcher**: ページタイトル後追い取得

## Development Commands

### Build Configuration
```bash
# Info.plistに追加必須
# NSCameraUsageDescription: "QRコード読み取りのためにカメラを使用します。"

# APIキー設定（外部レピュテーション使用時）
# .xcconfig または User-Defined Settings で注入
```

### Testing
```bash
# ユニットテスト実行（作成予定）
# UrlRiskEvaluatorTests - 危険度判定ロジック
# HistoryRepositoryTests - 50件上限と重複処理
```

## Safety Logic Implementation

### Risk Scoring (UrlRiskEvaluator)
端末内スコアリング基準:
- Punycode/紛らわしい文字: +3
- IP直打ちURL: +2  
- サブドメイン深さ>3: +1
- 有名ブランド語含むが公式でない: +3
- 疑義TLD (.zip/.mov等): +1

判定: 0-1=safe, 2-3=caution, 4+=danger
設定による調整: high=+1, low=-1

## UI/UX Guidelines

### 画面構成
1. **ScannerVC** - 起動直後にカメラ起動、即スキャン開始
2. **OpenConfirmVC** - danger/caution時の確認画面（優しい文言）
3. **HistoryVC** - UITableView、最大50件、タイトル付き表示
4. **SettingsVC** - 厳しさ(low/standard/high)、外部照会ON/OFF

### 配色
- 安全: 落ち着いた緑系
- 注意: 橙系
- 危険: 赤系（強調）

## Privacy & Security Rules
- **URL生値は外部送信禁止** - ドメインハッシュまたはeTLD+1のみ
- 履歴は端末内保存のみ（Core Data）
- ログにURL記録禁止
- テレメトリは匿名クラッシュ収集のみ許可

## Implementation Priority (from docs/tasks.md)
1. AppDelegate → ScannerViewController をrootに設定
2. QRScannerService実装（AVFoundation）
3. UrlRiskEvaluator実装（危険度判定）
4. Core Dataスタック構築（ScanRecordEntity）
5. HistoryRepository実装（50件制限）
6. 各画面実装（Scanner/History/Settings/OpenConfirm）
7. HtmlTitleFetcher実装（後追いタイトル取得）

## Testing Notes
- シミュレータではカメラ不可、実機テスト必須
- モック画像でUI確認可能
- オフライン動作必須（タイトル取得/外部照会除く）