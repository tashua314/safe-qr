import UIKit

/**
 * ScannerViewController専用のUI管理クラス
 * - UIコンポーネントの作成と配置
 * - レイアウト管理
 * - UI状態の更新
 * - ボタンスタイルの統一
 */
class ScannerUIManager: ScannerUIManagerProtocol {
    
    // MARK: - UI Components
    
    private(set) var cameraPreviewView: UIView!
    private(set) var guideLabel: UILabel!
    private(set) var scanOverlayView: UIView!
    private(set) var statusLabel: UILabel!
    private(set) var historyButton: UIButton!
    private(set) var settingsButton: UIButton!
    private(set) var lightButton: UIButton!
    
    // MARK: - Private Properties
    
    private weak var viewController: UIViewController?
    private var buttonActions: ButtonActions?
    
    // MARK: - Button Actions Container
    
    private struct ButtonActions {
        let historyAction: () -> Void
        let settingsAction: () -> Void
        let lightAction: () -> Void
    }
    
    // MARK: - Public Methods
    
    func setupUI(in viewController: UIViewController) {
        self.viewController = viewController
        
        createUIComponents()
        configureUIComponents()
        setupAutoLayout()
        configureInitialState()
    }
    
    func updateLayout() {
        guard let viewController = viewController,
              viewController.isViewLoaded,
              cameraPreviewView != nil else { 
            print("⚠️ UIManager: レイアウト更新をスキップ（初期化未完了）")
            return 
        }
        
        // メインスレッドでUI更新を確実に実行
        DispatchQueue.main.async {
            viewController.view.setNeedsLayout()
            viewController.view.layoutIfNeeded()
        }
    }
    
    func updateUI(for status: ScanStatus) {
        DispatchQueue.main.async { [weak self] in
            self?.updateStatusLabel(for: status)
            self?.updateOverlayAppearance(for: status)
            self?.updateButtonStates(for: status)
        }
    }
    
    func setButtonActions(
        historyAction: @escaping () -> Void,
        settingsAction: @escaping () -> Void,
        lightAction: @escaping () -> Void
    ) {
        self.buttonActions = ButtonActions(
            historyAction: historyAction,
            settingsAction: settingsAction,
            lightAction: lightAction
        )
        
        configureButtonActions()
    }
    
    // MARK: - UI Component Creation
    
    private func createUIComponents() {
        cameraPreviewView = UIView()
        guideLabel = UILabel()
        scanOverlayView = UIView()
        statusLabel = UILabel()
        historyButton = createOverlayButton(title: "履歴", systemImage: "clock")
        settingsButton = createOverlayButton(title: "設定", systemImage: "gearshape")
        lightButton = createOverlayButton(title: "ライト", systemImage: "flashlight.off.fill")
    }
    
    private func configureUIComponents() {
        configureCameraPreviewView()
        configureGuideLabel()
        configureScanOverlayView()
        configureStatusLabel()
    }
    
    // MARK: - Individual Component Configuration
    
    private func configureCameraPreviewView() {
        cameraPreviewView.backgroundColor = .black
        cameraPreviewView.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func configureGuideLabel() {
        guideLabel.text = "QRコードをカメラで読み取ってください"
        guideLabel.font = AppConstants.Fonts.body
        guideLabel.textColor = .white
        guideLabel.textAlignment = .center
        guideLabel.numberOfLines = 0
        guideLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // タッチイベントを通過させる
        guideLabel.isUserInteractionEnabled = false
    }
    
    private func configureScanOverlayView() {
        scanOverlayView.backgroundColor = .clear
        scanOverlayView.layer.borderColor = UIColor.white.cgColor
        scanOverlayView.layer.borderWidth = 2
        scanOverlayView.layer.cornerRadius = AppConstants.UI.overlayCornerRadius
        scanOverlayView.translatesAutoresizingMaskIntoConstraints = false
        
        // タッチイベントを通過させる
        scanOverlayView.isUserInteractionEnabled = false
        
        // スキャンエリアのアニメーション効果を追加
        addScanAnimation()
    }
    
    private func configureStatusLabel() {
        statusLabel.text = "スキャン準備中..."
        statusLabel.font = AppConstants.Fonts.caption
        statusLabel.textColor = .white
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // タッチイベントを通過させる
        statusLabel.isUserInteractionEnabled = false
    }
    
    // MARK: - Button Creation Helper
    
    private func createOverlayButton(title: String, systemImage: String) -> UIButton {
        let button = UIButton(type: .system)
        
        // iOS 15+ のUIButtonConfigurationを使用
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.filled()
            config.title = title
            config.image = UIImage(systemName: systemImage)
            config.imagePadding = 4
            config.contentInsets = NSDirectionalEdgeInsets(
                top: 8, 
                leading: 12, 
                bottom: 8, 
                trailing: 12
            )
            config.baseBackgroundColor = AppConstants.Colors.overlayBackground
            config.baseForegroundColor = .white
            config.cornerStyle = .medium
            
            button.configuration = config
        } else {
            // iOS 14以下のフォールバック
            button.setTitle(title, for: .normal)
            button.setImage(UIImage(systemName: systemImage), for: .normal)
            button.titleLabel?.font = AppConstants.Fonts.button
            button.setTitleColor(.white, for: .normal)
            button.tintColor = .white
            button.backgroundColor = AppConstants.Colors.overlayBackground
            button.layer.cornerRadius = AppConstants.UI.overlayCornerRadius
            button.contentEdgeInsets = AppConstants.UI.buttonPadding
            button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -4, bottom: 0, right: 4)
        }
        
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
    
    // MARK: - Auto Layout Setup
    
    private func setupAutoLayout() {
        guard let viewController = viewController else { return }
        let view = viewController.view!
        
        // Add all subviews
        view.addSubview(cameraPreviewView)
        view.addSubview(guideLabel)
        view.addSubview(scanOverlayView)
        view.addSubview(statusLabel)
        view.addSubview(historyButton)
        view.addSubview(settingsButton)
        view.addSubview(lightButton)
        
        // Camera Preview (Full screen)
        NSLayoutConstraint.activate([
            cameraPreviewView.topAnchor.constraint(equalTo: view.topAnchor),
            cameraPreviewView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cameraPreviewView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cameraPreviewView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Guide Label (Top center)
        NSLayoutConstraint.activate([
            guideLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            guideLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppConstants.UI.standardMargin),
            guideLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppConstants.UI.standardMargin)
        ])
        
        // Scan Overlay (Center)
        NSLayoutConstraint.activate([
            scanOverlayView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scanOverlayView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            scanOverlayView.widthAnchor.constraint(equalToConstant: 250),
            scanOverlayView.heightAnchor.constraint(equalToConstant: 250)
        ])
        
        // Status Label (Below overlay)
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: scanOverlayView.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppConstants.UI.standardMargin),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppConstants.UI.standardMargin)
        ])
        
        // History Button (Top left)
        NSLayoutConstraint.activate([
            historyButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AppConstants.UI.standardMargin),
            historyButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppConstants.UI.standardMargin)
        ])
        
        // Settings Button (Top right)
        NSLayoutConstraint.activate([
            settingsButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AppConstants.UI.standardMargin),
            settingsButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppConstants.UI.standardMargin)
        ])
        
        // Light Button (Bottom center)
        NSLayoutConstraint.activate([
            lightButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -AppConstants.UI.standardMargin),
            lightButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    // MARK: - Button Actions Configuration
    
    private func configureButtonActions() {
        guard let actions = buttonActions else { return }
        
        historyButton.addTarget(self, action: #selector(historyButtonTapped), for: .touchUpInside)
        settingsButton.addTarget(self, action: #selector(settingsButtonTapped), for: .touchUpInside)
        lightButton.addTarget(self, action: #selector(lightButtonTapped), for: .touchUpInside)
    }
    
    @objc private func historyButtonTapped() {
        addButtonTapAnimation(historyButton)
        buttonActions?.historyAction()
    }
    
    @objc private func settingsButtonTapped() {
        addButtonTapAnimation(settingsButton)
        buttonActions?.settingsAction()
    }
    
    @objc private func lightButtonTapped() {
        addButtonTapAnimation(lightButton)
        buttonActions?.lightAction()
    }
    
    // MARK: - UI State Updates
    
    private func updateStatusLabel(for status: ScanStatus) {
        guard let statusLabel = statusLabel else {
            print("⚠️ UIManager: statusLabel未初期化")
            return
        }
        
        switch status {
        case .ready:
            statusLabel.text = "QRコードをカメラに向けてください"
            statusLabel.textColor = .white
        case .processing:
            statusLabel.text = "処理中..."
            statusLabel.textColor = .systemYellow
        case .evaluated:
            statusLabel.text = "評価完了"
            statusLabel.textColor = .systemGreen
        case .error:
            statusLabel.text = "エラーが発生しました"
            statusLabel.textColor = .systemRed
        }
    }
    
    private func updateOverlayAppearance(for status: ScanStatus) {
        guard let scanOverlayView = scanOverlayView else {
            print("⚠️ UIManager: scanOverlayView未初期化")
            return
        }
        
        switch status {
        case .ready:
            scanOverlayView.layer.borderColor = UIColor.white.cgColor
        case .processing:
            scanOverlayView.layer.borderColor = UIColor.systemYellow.cgColor
        case .evaluated:
            scanOverlayView.layer.borderColor = UIColor.systemGreen.cgColor
        case .error:
            scanOverlayView.layer.borderColor = UIColor.systemRed.cgColor
        }
    }
    
    private func updateButtonStates(for status: ScanStatus) {
        guard let historyButton = historyButton,
              let settingsButton = settingsButton,
              let lightButton = lightButton else {
            print("⚠️ UIManager: ボタン未初期化")
            return
        }
        
        let isEnabled = (status == .ready || status == .evaluated)
        
        historyButton.isEnabled = isEnabled
        settingsButton.isEnabled = isEnabled
        lightButton.isEnabled = isEnabled
        
        let alpha: CGFloat = isEnabled ? 1.0 : 0.6
        historyButton.alpha = alpha
        settingsButton.alpha = alpha
    }
    
    func updateLightButtonState(_ isEnabled: Bool) {
        guard let lightButton = lightButton else {
            print("⚠️ UIManager: lightButton未初期化")
            return
        }
        
        let imageName = isEnabled ? "flashlight.on.fill" : "flashlight.off.fill"
        
        if #available(iOS 15.0, *) {
            var config = lightButton.configuration
            config?.image = UIImage(systemName: imageName)
            lightButton.configuration = config
        } else {
            lightButton.setImage(UIImage(systemName: imageName), for: .normal)
        }
        
        lightButton.backgroundColor = isEnabled ? 
            AppConstants.Colors.overlayBackground.withAlphaComponent(0.8) : 
            AppConstants.Colors.overlayBackground
    }
    
    // MARK: - Initial State Configuration
    
    private func configureInitialState() {
        updateUI(for: .ready)
    }
    
    // MARK: - Animations
    
    private func addScanAnimation() {
        // スキャンエリアの点滅アニメーション
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1.0
        animation.toValue = 0.5
        animation.duration = 1.0
        animation.repeatCount = .infinity
        animation.autoreverses = true
        
        scanOverlayView.layer.add(animation, forKey: "scanAnimation")
    }
    
    private func addButtonTapAnimation(_ button: UIButton) {
        UIView.animate(
            withDuration: AppConstants.UI.animationDuration / 2,
            animations: {
                button.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            },
            completion: { _ in
                UIView.animate(withDuration: AppConstants.UI.animationDuration / 2) {
                    button.transform = .identity
                }
            }
        )
    }
    
    // MARK: - Public Accessors for ViewController
    
    func getCameraPreviewView() -> UIView {
        return cameraPreviewView
    }
}