# メモリリーク検証ガイド

SafeQRアプリのメモリリーク検証手順とチェックポイント

## 🎯 検証目的

1. **メモリリークの検出** - 長時間使用でのメモリ使用量増加を防ぐ
2. **パフォーマンス最適化** - 快適な QR スキャン体験の維持
3. **バッテリー消費削減** - 無駄なバックグラウンド処理の排除

## 🧪 テスト実行手順

### 1. ユニットテストでの基本検証

```bash
# メモリリークテストを実行
xcodebuild test -scheme SafeQR -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:SafeQRTests/MemoryLeakTests
```

**主要テストケース:**
- `testQRScannerServiceMemoryManagement` - AVCaptureSession のリーク検証
- `testScannerViewModelMemoryManagement` - ViewModel の循環参照チェック
- `testDIContainerMemoryManagement` - DIContainer のファクトリリーク検証
- `testCoreDataStackMemoryManagement` - Core Data のコンテキストリーク検証
- `testLongRunningMemoryUsage` - 30秒間の連続動作テスト
- `testMemoryPressure` - 大量オブジェクト生成でのメモリ圧迫テスト

### 2. Instruments でのプロファイリング

#### 2.1 Leaks Instrument の使用

1. **Xcode → Product → Profile** を選択
2. **Leaks** テンプレートを選択
3. アプリを起動して以下のシナリオを実行:

**基本シナリオ (10分間):**
```
1. QRスキャン画面で待機 (2分)
2. テストQRボタンを10回タップ
3. 履歴画面を開いて閉じる (5回)
4. 設定画面を開いて閉じる (5回)
5. 危険URLのテストを実行 (5回)
6. 注意URLのテストを実行 (5回)
7. QRスキャン画面で待機 (3分)
```

**集中シナリオ (20分間):**
```
1. 連続50回のQRスキャンシミュレーション
2. 履歴の大量生成（50件まで埋める）
3. アプリをバックグラウンド/フォアグラウンド切り替え (10回)
4. カメラ権限の取り消し→再許可
5. 外部API ON/OFF 切り替え (10回)
```

#### 2.2 Allocations Instrument の使用

1. **Allocations** テンプレートを選択
2. **Mark Generation** を使用して世代別メモリ管理を監視
3. 以下の操作後にマークを作成:
   - アプリ起動直後
   - 10回QRスキャン後
   - 20回QRスキャン後
   - 50回QRスキャン後

#### 2.3 Activity Monitor での監視

```bash
# アプリのメモリ使用量をリアルタイム監視
instruments -t "Activity Monitor" -D trace_output.trace SafeQR.app
```

## 🚨 重要チェックポイント

### 1. メモリリークが疑われる箇所

#### AVCaptureSession 関連
- [ ] `QRScannerService.setupCaptureSession()` の適切な解放
- [ ] `AVCaptureVideoPreviewLayer` のメモリ保持
- [ ] メタデータ出力デリゲートの循環参照

**確認方法:**
```swift
// QRScannerService.swift:294 あたり
// captureSession が適切に nil になっているかデバッガーで確認
```

#### NotificationCenter Observer
- [ ] `ScannerViewController` の Combine cancellables 解放
- [ ] `ScannerViewModel` のNotificationCenter投稿処理

**確認方法:**
```swift
// ScannerViewController.swift:90
// deinit で cancellables.removeAll() が呼ばれているか確認
```

#### DIContainer 循環参照
- [ ] `[unowned self]` の安全性
- [ ] ファクトリクロージャの参照サイクル

**確認方法:**
```swift
// DIContainer.swift:104, 115
// unowned self が premature deallocation を引き起こしていないか
```

### 2. パフォーマンス閾値

| メトリック | 期待値 | 警告値 | 危険値 |
|-----------|--------|--------|--------|
| 起動時メモリ | < 50MB | 50-80MB | > 80MB |
| QRスキャン中 | < 100MB | 100-150MB | > 150MB |
| 10分使用後 | 起動時+20MB | 起動時+50MB | 起動時+100MB |
| 50回スキャン後 | 起動時+30MB | 起動時+70MB | 起動時+150MB |

### 3. CPU使用率

```bash
# CPUプロファイリング
instruments -t "Time Profiler" SafeQR.app

# 期待値:
# - QRスキャン待機中: < 5%
# - QRスキャン実行中: < 30%
# - URL評価中: < 15%
```

## 🔧 メモリリーク修正パターン

### Pattern 1: weak self in closures

```swift
// 修正前
someService.performTask { result in
    self.handleResult(result)  // 強参照サイクル
}

// 修正後
someService.performTask { [weak self] result in
    self?.handleResult(result)
}
```

### Pattern 2: Combine cancellables

```swift
// ViewControllerで
private var cancellables = Set<AnyCancellable>()

deinit {
    cancellables.removeAll()  // 必須
}
```

### Pattern 3: AVCaptureSession cleanup

```swift
deinit {
    captureSession?.stopRunning()
    captureSession = nil
    previewLayer?.removeFromSuperlayer()
}
```

### Pattern 4: Timer invalidation

```swift
private var refreshTimer: Timer?

deinit {
    refreshTimer?.invalidate()
    refreshTimer = nil
}
```

## 📊 レポート生成

### Instruments結果の解析

1. **Leaks タブ**:
   - リーク数: 0個が目標
   - リークサイズ: 0 bytes が目標

2. **Allocations タブ**:
   - Persistent Growth を確認
   - Mark Generation 間の増加を監視

3. **Activity Monitor**:
   - Physical Memory の推移
   - CPU使用率の異常値

### 自動化スクリプト

```bash
#!/bin/bash
# メモリテスト自動実行スクリプト

echo "🧪 Starting automated memory leak testing..."

# 1. ユニットテスト実行
echo "📋 Running unit tests..."
xcodebuild test -scheme SafeQR -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:SafeQRTests/MemoryLeakTests

# 2. Instruments プロファイリング (バックグラウンド)
echo "🔍 Starting Instruments profiling..."
instruments -t "Leaks" -D leaks_trace.trace SafeQR.app &
INSTRUMENTS_PID=$!

# 3. アプリ操作の自動化 (UI Testing)
echo "🤖 Running automated UI testing..."
xcodebuild test -scheme SafeQR -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:SafeQRUITests/MemoryUsageUITests

# 4. 結果の集約
echo "📊 Collecting results..."
kill $INSTRUMENTS_PID
echo "✅ Memory leak testing completed"
```

## 🎯 合格基準

### ✅ 合格条件
- [ ] Leaks Instrument でリーク検出 **0件**
- [ ] 30分連続使用でメモリ増加 **< 100MB**
- [ ] CPU使用率 待機中 **< 5%**、スキャン中 **< 30%**
- [ ] UI操作の応答性維持 **< 100ms**
- [ ] バックグラウンド復帰時の正常動作
- [ ] メモリ警告時の適切な対応

### ❌ 修正が必要な症状
- Leaks Instrument でのリーク検出
- 連続使用でのメモリ使用量の線形増加  
- アプリの応答性低下
- バックグラウンド復帰時のクラッシュ
- メモリ警告の頻発

---

**実行頻度**: リリース前必須、コード変更時推奨  
**担当者**: 開発者 + QA  
**所要時間**: 基本検証 30分、詳細検証 2時間