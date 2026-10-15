import Combine
import SafariServices
import UIKit

/**
 * QRスキャナーのメイン画面（MVVM構造）
 * - ViewModelによるビジネスロジック分離
 * - UIManagerによるUI管理分離
 * - DIによる依存性注入
 * - Combineによるリアクティブな状態管理
 */
class ScannerViewController: UIViewController {
    // MARK: - MVVM Dependencies

    /// ビジネスロジックを担当するViewModel
    private let viewModel: ScannerViewModel

    /// UI管理を担当するUIManager
    private let uiManager: ScannerUIManagerProtocol

    /// QRスキャナーサービス（DI）
    private let qrScannerService: QRScannerServiceProtocol

    // MARK: - Reactive Properties

    /// Combineのキャンセレーション管理
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Properties

    /// 現在スキャン中かどうか
    private var isScanning = false

    // MARK: - Initialization

    init(
        viewModel: ScannerViewModel? = nil,
        uiManager: ScannerUIManagerProtocol? = nil,
        qrScannerService: QRScannerServiceProtocol? = nil
    ) {
        self.viewModel = viewModel ?? resolve(ScannerViewModel.self)
        self.uiManager = uiManager ?? resolve(ScannerUIManagerProtocol.self)
        self.qrScannerService = qrScannerService ?? resolve(QRScannerServiceProtocol.self)

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        // DIを使って依存関係を解決
        viewModel = resolve(ScannerViewModel.self)
        uiManager = resolve(ScannerUIManagerProtocol.self)
        qrScannerService = resolve(QRScannerServiceProtocol.self)

        super.init(coder: coder)
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
        setupQRScanner()
        setupNotifications()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startScanning()
        viewModel.resetScan()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateCameraPreviewLayout()

        // UIManagerが完全に初期化されている場合のみレイアウト更新
        if isViewLoaded {
            uiManager.updateLayout()
        }
    }

    deinit {
        cancellables.removeAll()
    }

    // MARK: - Setup Methods

    /**
     * UI要素の初期設定（MVVM版）
     * UIManagerに委譲
     */
    private func setupUI() {
        view.backgroundColor = .black

        // UIManagerにUI構築を委譲
        uiManager.setupUI(in: self)

        // ボタンアクションの設定
        uiManager.setButtonActions(
            historyAction: { [weak self] in self?.showHistory() },
            settingsAction: { [weak self] in self?.showSettings() },
            lightAction: { [weak self] in self?.toggleLight() }
        )
    }

    /**
     * ViewModelとのバインディング設定
     */
    private func setupBindings() {
        // スキャン状態の監視
        viewModel.$scanStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.uiManager.updateUI(for: status)
            }
            .store(in: &cancellables)

        // 評価結果の監視
        viewModel.$evaluationResult
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                self?.handleEvaluationResult(result)
            }
            .store(in: &cancellables)

        // エラーメッセージの監視
        viewModel.$errorMessage
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.showError(error)
            }
            .store(in: &cancellables)

        // ライト状態の監視
        viewModel.$isLightEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEnabled in
                if let uiManager = self?.uiManager as? ScannerUIManager {
                    uiManager.updateLightButtonState(isEnabled)
                }
            }
            .store(in: &cancellables)
    }

    /**
     * 通知の設定
     */
    private func setupNotifications() {
        // URL開く要求の監視
        NotificationCenter.default
            .publisher(for: .openURLRequested)
            .compactMap { $0.object as? String }
            .sink { [weak self] url in
                self?.openURL(url)
            }
            .store(in: &cancellables)

        // 警告ダイアログ表示の監視
        NotificationCenter.default
            .publisher(for: .showWarningDialog)
            .compactMap { $0.object as? [String: Any] }
            .sink { [weak self] dialogInfo in
                self?.showWarningDialog(dialogInfo)
            }
            .store(in: &cancellables)
    }

    // MARK: - QR Scanner Setup

    /**
     * QRスキャナーの設定
     */
    private func setupQRScanner() {
        // カメラアクセス許可をチェック
        qrScannerService.requestCameraPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.configureQRScanner()
                } else {
                    self?.showCameraPermissionError()
                }
            }
        }

        // QRコード検出結果の監視
        qrScannerService.scanResult
            .sink { [weak self] qrCode in
                self?.viewModel.processDetectedQRCode(qrCode)
            }
            .store(in: &cancellables)
    }

    /**
     * QRスキャナーの実際の設定
     */
    private func configureQRScanner() {
        guard let cameraPreviewView = (uiManager as? ScannerUIManager)?.getCameraPreviewView() else {
            return
        }

        qrScannerService.setupCaptureSession(in: cameraPreviewView)
    }

    // MARK: - Scanner Control

    /**
     * スキャン開始
     */
    private func startScanning() {
        guard !isScanning else { return }

        qrScannerService.startScanning()
        isScanning = true

        print("📷 QRスキャン開始")
    }

    /**
     * スキャン停止
     */
    private func stopScanning() {
        guard isScanning else { return }

        qrScannerService.stopScanning()
        isScanning = false

        print("📷 QRスキャン停止")
    }

    /**
     * カメラプレビューのレイアウト更新
     */
    private func updateCameraPreviewLayout() {
        guard let cameraPreviewView = (uiManager as? ScannerUIManager)?.getCameraPreviewView() else {
            return
        }

        qrScannerService.updatePreviewLayer(frame: cameraPreviewView.bounds)
    }

    // MARK: - Event Handlers

    /**
     * 評価結果の処理
     */
    private func handleEvaluationResult(_ result: URLEvaluationResult) {
        switch result.safetyLevel {
        case .safe:
            // 安全なURLはそのまま開く
            viewModel.proceedWithURL(result.url, safetyLevel: result.safetyLevel)

        case .caution, .danger:
            // 警告・危険なURLは確認ダイアログを表示
            showConfirmationDialog(for: result)
        }
    }

    /**
     * エラーの表示
     */
    private func showError(_ message: String) {
        let alert = UIAlertController(
            title: "エラー",
            message: message,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.viewModel.resetScan()
        })

        present(alert, animated: true)
    }

    /**
     * 確認ダイアログの表示
     */
    private func showConfirmationDialog(for result: URLEvaluationResult) {
        let confirmVC = OpenConfirmViewController(
            url: result.url,
            safetyLevel: result.safetyLevel,
            detectedIssues: result.detectedIssues
        )

        confirmVC.onUserDecision = { [weak self] shouldOpen in
            if shouldOpen {
                self?.viewModel.proceedWithURL(result.url, safetyLevel: result.safetyLevel)
            } else {
                self?.viewModel.resetScan()
            }
        }

        present(confirmVC, animated: true)
    }

    /**
     * 警告ダイアログの表示（通知経由）
     */
    private func showWarningDialog(_ dialogInfo: [String: Any]) {
        guard let url = dialogInfo["url"] as? String,
              let safetyLevelRaw = dialogInfo["safetyLevel"] as? Int16,
              let safetyLevel = SafetyLevel(rawValue: safetyLevelRaw),
              let detectedIssues = dialogInfo["detectedIssues"] as? [String] else {
            return
        }

        let result = URLEvaluationResult(
            url: url,
            safetyLevel: safetyLevel,
            evaluationMethod: .local,
            responseTime: 0,
            detectedIssues: detectedIssues
        )

        showConfirmationDialog(for: result)
    }

    /**
     * 確認メッセージの作成
     */
    private func createConfirmationMessage(for result: URLEvaluationResult) -> String {
        var message = "このサイトにアクセスしますか？\n\n"
        message += "URL: \(result.url)\n"
        message += "安全性: \(result.safetyLevel.displayName)\n"

        if !result.detectedIssues.isEmpty {
            message += "検出された問題: \(result.detectedIssues.joined(separator: ", "))\n"
        }

        message += "\n注意して進んでください。"
        return message
    }

    // MARK: - Button Actions

    /**
     * ライトの切り替え
     */
    private func toggleLight() {
        viewModel.toggleLight()
    }

    /**
     * 履歴画面を表示
     */
    private func showHistory() {
        let historyVC = HistoryViewController()
        let navController = UINavigationController(rootViewController: historyVC)
        present(navController, animated: true)
    }

    /**
     * 設定画面を表示
     */
    private func showSettings() {
        let settingsVC = SettingsViewController()
        let navController = UINavigationController(rootViewController: settingsVC)
        present(navController, animated: true)
    }

    /**
     * URLを開く
     */
    private func openURL(_ url: String) {
        guard let urlObject = URL(string: url) else {
            showError("無効なURLです")
            return
        }

        let safariVC = SFSafariViewController(url: urlObject)
        present(safariVC, animated: true)
    }

    // MARK: - Error Handling

    /**
     * カメラアクセス許可エラーの表示
     */
    private func showCameraPermissionError() {
        let alert = UIAlertController(
            title: "カメラへのアクセス許可が必要です",
            message: "QRコードを読み取るために、設定からカメラへのアクセスを許可してください。",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "設定を開く", style: .default) { _ in
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        })

        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))

        present(alert, animated: true)
    }
}
