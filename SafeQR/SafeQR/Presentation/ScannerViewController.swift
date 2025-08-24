import UIKit
import SafariServices

/**
 * QRスキャナーのメイン画面
 * - 起動直後にカメラ起動、即スキャン開始
 * - QR検出時に危険度を判定し、必要に応じて確認画面を表示
 * - 安全なURLはそのままSafariで開く
 * - 履歴に自動保存、後追いでタイトル取得
 */
class ScannerViewController: UIViewController {
    
    // MARK: - UI Components
    
    /// カメラプレビュー用のベースビュー
    private let cameraPreviewView = UIView()
    
    /// ガイドメッセージ用ラベル
    private let guideLabel = UILabel()
    
    /// QRコードの枠を示すオーバーレイビュー
    private let scanOverlayView = UIView()
    
    /// 履歴ボタン（左上）
    private let historyButton = UIButton(type: .system)
    
    /// 設定ボタン（右上）
    private let settingsButton = UIButton(type: .system)
    
    /// ライト（フラッシュライト）トグルボタン
    private let lightButton = UIButton(type: .system)
    
    /// スキャン状態を示すインジケータ
    private let statusLabel = UILabel()
    
    // MARK: - Service Dependencies
    
    /// QRスキャナーサービス
    private let qrScannerService = QRScannerService()
    
    /// URL危険度評価サービス
    private let urlRiskEvaluator = UrlRiskEvaluator()
    
    /// 履歴リポジトリ
    private let historyRepository = HistoryRepository()
    
    /// 外部レピュテーション照会クライアント
    private let reputationClient = ReputationClient()
    
    /// HTMLタイトル取得クライアント
    private let titleFetcher = HtmlTitleFetcher()
    
    // MARK: - Properties
    
    /// 現在スキャン中かどうか
    private var isScanning = false
    
    /// ライト（フラッシュライト）がオンかどうか
    private var isLightOn = false
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupQRScanner()
        setupNavigationBar()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 画面が表示される度にスキャン開始
        startScanning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 画面が非表示になる時はスキャン停止
        stopScanning()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // レイアウト更新時にカメラプレビューも更新
        qrScannerService.updatePreviewLayer(frame: cameraPreviewView.bounds)
    }
    
    // MARK: - UI Setup
    
    /**
     * UI要素の初期設定
     * iOS 18.5+対応のためAutoLayoutをコードで構築
     */
    private func setupUI() {
        view.backgroundColor = .black
        
        setupCameraPreviewView()
        setupGuideLabel()
        setupScanOverlay()
        setupControlButtons()
        setupStatusLabel()
        setupConstraints()
    }
    
    /**
     * カメラプレビュービューの設定
     */
    private func setupCameraPreviewView() {
        cameraPreviewView.backgroundColor = .black
        cameraPreviewView.translatesAutoresizingMaskIntoConstraints = false
        cameraPreviewView.isUserInteractionEnabled = true  // タッチイベントを有効化
        view.addSubview(cameraPreviewView)
    }
    
    /**
     * ガイドラベルの設定
     * ITリテラシー低めのユーザー向けに分かりやすく表示
     */
    private func setupGuideLabel() {
        guideLabel.text = "QRコードにかざしてください"
        guideLabel.textColor = .white
        guideLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        guideLabel.textAlignment = .center
        guideLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        guideLabel.layer.cornerRadius = 8
        guideLabel.layer.masksToBounds = true
        guideLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Dynamic Type対応
        guideLabel.adjustsFontForContentSizeCategory = true
        guideLabel.isUserInteractionEnabled = false  // タッチイベントを通す
        
        view.addSubview(guideLabel)
    }
    
    /**
     * スキャンオーバーレイビューの設定
     * QRコードの読み取り領域を視覚的に示す
     */
    private func setupScanOverlay() {
        scanOverlayView.backgroundColor = .clear
        scanOverlayView.layer.borderColor = UIColor.systemGreen.cgColor
        scanOverlayView.layer.borderWidth = 2
        scanOverlayView.layer.cornerRadius = 12
        scanOverlayView.translatesAutoresizingMaskIntoConstraints = false
        scanOverlayView.isUserInteractionEnabled = false  // タッチイベントを通す
        view.addSubview(scanOverlayView)
    }
    
    /**
     * 制御ボタン群の設定
     */
    private func setupControlButtons() {
        setupHistoryButton()
        setupSettingsButton()
        setupLightButton()
    }
    
    /**
     * 履歴ボタンの設定
     */
    private func setupHistoryButton() {
        historyButton.setTitle("履歴", for: .normal)
        historyButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        historyButton.setTitleColor(.white, for: .normal)
        historyButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        historyButton.layer.cornerRadius = 8
        historyButton.translatesAutoresizingMaskIntoConstraints = false
        
        // タップ領域を44pt以上に設定（アクセシビリティ）
        historyButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        
        historyButton.addTarget(self, action: #selector(historyButtonTapped), for: .touchUpInside)
        view.addSubview(historyButton)
    }
    
    /**
     * 設定ボタンの設定
     */
    private func setupSettingsButton() {
        settingsButton.setTitle("設定", for: .normal)
        settingsButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        settingsButton.setTitleColor(.white, for: .normal)
        settingsButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        settingsButton.layer.cornerRadius = 8
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        
        settingsButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        
        settingsButton.addTarget(self, action: #selector(settingsButtonTapped), for: .touchUpInside)
        view.addSubview(settingsButton)
    }
    
    /**
     * ライトボタンの設定
     */
    private func setupLightButton() {
        lightButton.setTitle("💡", for: .normal)
        lightButton.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        lightButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        lightButton.layer.cornerRadius = 25
        lightButton.translatesAutoresizingMaskIntoConstraints = false
        
        lightButton.addTarget(self, action: #selector(lightButtonTapped), for: .touchUpInside)
        view.addSubview(lightButton)
    }
    
    /**
     * ステータスラベルの設定
     */
    private func setupStatusLabel() {
        statusLabel.text = "スキャンを準備中..."
        statusLabel.textColor = .white
        statusLabel.font = UIFont.systemFont(ofSize: 14)
        statusLabel.textAlignment = .center
        statusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        statusLabel.layer.cornerRadius = 6
        statusLabel.layer.masksToBounds = true
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.isUserInteractionEnabled = false  // タッチイベントを通す
        
        view.addSubview(statusLabel)
    }
    
    /**
     * Auto Layout制約の設定
     */
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // カメラプレビュービュー（全画面）
            cameraPreviewView.topAnchor.constraint(equalTo: view.topAnchor),
            cameraPreviewView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cameraPreviewView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cameraPreviewView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 履歴ボタン（左上）
            historyButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            historyButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            // 設定ボタン（右上）
            settingsButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            settingsButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // スキャンオーバーレイ（中央）
            scanOverlayView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scanOverlayView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            scanOverlayView.widthAnchor.constraint(equalToConstant: 250),
            scanOverlayView.heightAnchor.constraint(equalToConstant: 250),
            
            // ガイドラベル（オーバーレイの下）
            guideLabel.topAnchor.constraint(equalTo: scanOverlayView.bottomAnchor, constant: 20),
            guideLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            guideLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -40),
            
            // ライトボタン（右下）
            lightButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            lightButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -80),
            lightButton.widthAnchor.constraint(equalToConstant: 50),
            lightButton.heightAnchor.constraint(equalToConstant: 50),
            
            // ステータスラベル（下部）
            statusLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -40)
        ])
    }
    
    /**
     * ナビゲーションバーの設定
     */
    private func setupNavigationBar() {
        // ナビゲーションバーを透明にして全画面表示
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    // MARK: - QR Scanner Setup
    
    /**
     * QRスキャナーサービスの初期設定
     */
    private func setupQRScanner() {
        qrScannerService.delegate = self
        qrScannerService.setupCamera(in: cameraPreviewView)
    }
    
    /**
     * スキャン開始
     */
    private func startScanning() {
        guard !isScanning else { return }
        
        qrScannerService.startScanning()
        isScanning = true
        
        updateStatusLabel("QRコードをスキャン中...")
        animateScanOverlay()
    }
    
    /**
     * スキャン停止
     */
    private func stopScanning() {
        guard isScanning else { return }
        
        qrScannerService.stopScanning()
        isScanning = false
        
        updateStatusLabel("スキャン停止中")
        stopScanOverlayAnimation()
    }
    
    // MARK: - UI Updates
    
    /**
     * ステータスラベルの更新
     * @param message: 表示するメッセージ
     */
    private func updateStatusLabel(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.statusLabel.text = message
        }
    }
    
    /**
     * スキャンオーバーレイのアニメーション開始
     */
    private func animateScanOverlay() {
        UIView.animate(withDuration: 1.0, delay: 0, options: [.repeat, .autoreverse], animations: {
            self.scanOverlayView.alpha = 0.3
        }, completion: nil)
    }
    
    /**
     * スキャンオーバーレイのアニメーション停止
     */
    private func stopScanOverlayAnimation() {
        scanOverlayView.layer.removeAllAnimations()
        scanOverlayView.alpha = 1.0
    }
    
    // MARK: - Button Actions
    
    /**
     * 履歴ボタンタップ処理
     */
    @objc private func historyButtonTapped() {
        let historyVC = HistoryViewController()
        let navController = UINavigationController(rootViewController: historyVC)
        present(navController, animated: true)
    }
    
    /**
     * 設定ボタンタップ処理
     */
    @objc private func settingsButtonTapped() {
        let settingsVC = SettingsViewController()
        let navController = UINavigationController(rootViewController: settingsVC)
        present(navController, animated: true)
    }
    
    /**
     * ライトボタンタップ処理
     */
    @objc private func lightButtonTapped() {
        // フラッシュライトの実装は後で追加
        // 現在は視覚的な反応のみ
        isLightOn.toggle()
        lightButton.backgroundColor = isLightOn ? 
            UIColor.yellow.withAlphaComponent(0.8) : 
            UIColor.black.withAlphaComponent(0.6)
    }
    
    // MARK: - QR Code Processing
    
    /**
     * QRコード検出後の処理フロー
     * 1. URL危険度評価
     * 2. 外部レピュテーション照会
     * 3. 安全性に応じた動作
     * 4. 履歴保存
     * @param qrCode: 検出されたQRコードの文字列
     */
    private func processDetectedQRCode(_ qrCode: String) {
        updateStatusLabel("URL安全性を確認中...")
        
        // 1. 端末内危険度評価
        let localSafety = urlRiskEvaluator.evaluate(url: qrCode)
        
        // 2. 外部レピュテーション照会（並行実行）
        reputationClient.checkReputation(for: qrCode) { [weak self] result in
            DispatchQueue.main.async {
                self?.handleReputationResult(url: qrCode, localSafety: localSafety, reputationResult: result)
            }
        }
    }
    
    /**
     * レピュテーション照会結果の処理
     * @param url: 対象URL
     * @param localSafety: 端末内評価結果
     * @param reputationResult: 外部レピュテーション結果
     */
    private func handleReputationResult(
        url: String,
        localSafety: SafetyLevel,
        reputationResult: Result<ReputationClient.ReputationResult, ReputationClient.ReputationError>
    ) {
        
        // 外部レピュテーション結果を考慮した最終判定
        let finalSafety: SafetyLevel
        
        switch reputationResult {
        case .success(let reputation):
            // 外部結果がある場合はより危険な方を採用
            if let externalSafety = reputation.safetyLevel {
                finalSafety = max(localSafety, externalSafety)
            } else {
                finalSafety = localSafety // 外部結果が不明な場合は端末内判定を使用
            }
        case .failure:
            finalSafety = localSafety // 外部照会失敗時は端末内判定を使用
        }
        
        // 安全性に応じた動作
        switch finalSafety {
        case .safe:
            // 安全：そのまま開く
            saveToHistoryAndOpen(url: url, safety: finalSafety)
            
        case .caution, .danger:
            // 注意・危険：確認画面を表示
            showConfirmationDialog(url: url, safety: finalSafety)
        }
        
        updateStatusLabel("スキャン完了")
        
        // スキャンを一時停止（1秒後に再開）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.startScanning()
        }
    }
    
    /**
     * 確認ダイアログの表示
     * @param url: 対象URL
     * @param safety: 安全性レベル
     */
    private func showConfirmationDialog(url: String, safety: SafetyLevel) {
        let confirmVC = OpenConfirmViewController(url: url, safetyLevel: safety)
        
        // 確認画面からの結果を受け取る
        confirmVC.onUserDecision = { [weak self] shouldOpen in
            if shouldOpen {
                self?.saveToHistoryAndOpen(url: url, safety: safety)
            }
        }
        
        present(confirmVC, animated: true)
    }
    
    /**
     * 履歴保存とURL開く処理
     * @param url: 対象URL
     * @param safety: 安全性レベル
     */
    private func saveToHistoryAndOpen(url: String, safety: SafetyLevel) {
        // 履歴に保存
        let domainHash = ScanRecord.generateDomainHash(from: url)
        let scanRecord = ScanRecord(url: url, safety: safety, domainHash: domainHash)
        historyRepository.upsertScanRecord(scanRecord)
        
        // 後追いでタイトル取得（バックグラウンド処理）
        fetchTitleInBackground(for: scanRecord)
        
        // URLを開く
        openURL(url)
    }
    
    /**
     * URLを安全にSafariで開く
     * @param url: 開くURL
     */
    private func openURL(_ url: String) {
        guard let urlObject = URL(string: url) else {
            showErrorAlert("無効なURLです")
            return
        }
        
        // SFSafariViewControllerでアプリ内ブラウジング
        let safariVC = SFSafariViewController(url: urlObject)
        safariVC.modalPresentationStyle = .pageSheet
        present(safariVC, animated: true)
    }
    
    /**
     * バックグラウンドでのタイトル取得
     * @param scanRecord: 対象のスキャンレコード
     */
    private func fetchTitleInBackground(for scanRecord: ScanRecord) {
        titleFetcher.fetchTitle(from: scanRecord.url) { [weak self] result in
            switch result {
            case .success(let titleResult):
                if let title = titleResult.title {
                    // タイトル取得成功時はCore Dataを更新
                    var updatedRecord = scanRecord
                    updatedRecord.title = title
                    self?.historyRepository.upsertScanRecord(updatedRecord)
                }
            case .failure(let error):
                print("タイトル取得失敗: \\(error.localizedDescription)")
                // エラーは無視（履歴表示時にドメインを表示）
            }
        }
    }
    
    /**
     * エラーアラートの表示
     * @param message: エラーメッセージ
     */
    private func showErrorAlert(_ message: String) {
        let alert = UIAlertController(title: "エラー", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - QRScannerServiceDelegate

extension ScannerViewController: QRScannerServiceDelegate {
    
    /**
     * QRコード検出時のコールバック
     * @param service: QRスキャナーサービス
     * @param code: 検出されたQRコード文字列
     */
    func qrScannerService(_ service: QRScannerService, didDetectQRCode code: String) {
        // スキャン一時停止
        stopScanning()
        
        // URL妥当性の簡易チェック
        guard isValidURL(code) else {
            updateStatusLabel("無効なQRコードです")
            // 1秒後にスキャン再開
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.startScanning()
            }
            return
        }
        
        // QRコード処理開始
        processDetectedQRCode(code)
    }
    
    /**
     * QRスキャナーエラー時のコールバック
     * @param service: QRスキャナーサービス
     * @param error: 発生したエラー
     */
    func qrScannerService(_ service: QRScannerService, didFailWithError error: QRScannerServiceError) {
        DispatchQueue.main.async { [weak self] in
            self?.updateStatusLabel(error.localizedDescription)
            self?.showErrorAlert(error.localizedDescription)
        }
    }
    
    /**
     * URL妥当性の簡易チェック
     * @param urlString: チェックするURL文字列
     * @return: 妥当なURLかどうか
     */
    private func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let scheme = url.scheme else {
            return false
        }
        
        // HTTPSまたはHTTPのみ許可
        return scheme == "http" || scheme == "https"
    }
}
