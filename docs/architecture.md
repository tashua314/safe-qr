# アーキテクチャ（UIKit + クリーン分離）

## レイヤ
- **Presentation（UIKit）**: 画面/入力/案内
- **Domain**: ルール/評価（Safety, Entities, Repository IF）
- **Data**: Core Data/メタデータ取得/レピュテーション

## 主なコンポーネント
- QRScannerService（AVCaptureSession管理、URL検出コールバック）
- UrlRiskEvaluator（端末内スコアリング）
- ReputationClient（外部判定、URL生値は送らずドメインハッシュ等）
- HistoryRepository（最大50件制御、visitCount/更新日時）
- HtmlTitleFetcher（<title>抽出、短いタイムアウト）
- SFSafariViewControllerラッパ（アプリ内安全ブラウズ）

## フロー（簡略）
1. 起動→ScannerVCでカメラ権限→セッション開始
2. URL検出→Normalizer→RiskEvaluator（+ReputationClient）
3. level==safe → 直接開く／caution/danger → OpenConfirmVC
4. 開く選択時にHistoryRepository.upsert（タイトルは後追い取得タスク）
