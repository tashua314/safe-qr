import UIKit

/**
 * URL開封確認ダイアログ
 * 危険度が注意（caution）または危険（danger）の場合に表示
 * ITリテラシーが低いユーザーでも理解しやすい優しい文言と明確なボタン配置
 */
class OpenConfirmViewController: UIViewController {
    
    // MARK: - Properties
    
    /// 対象のURL
    private let url: String
    
    /// 安全性レベル
    private let safetyLevel: SafetyLevel
    
    /// ユーザーの判断結果を通知するコールバック
    var onUserDecision: ((Bool) -> Void)?
    
    // MARK: - UI Components
    
    /// 背景を暗くするビュー
    private let backgroundView = UIView()
    
    /// メインのダイアログコンテナ
    private let dialogContainer = UIView()
    
    /// 警告アイコン
    private let warningIconLabel = UILabel()
    
    /// タイトルラベル（「危険な可能性があります」など）
    private let titleLabel = UILabel()
    
    /// URLを表示するラベル
    private let urlLabel = UILabel()
    
    /// 説明文ラベル
    private let descriptionLabel = UILabel()
    
    /// アドバイスラベル
    private let adviceLabel = UILabel()
    
    /// ボタンを格納するスタックビュー
    private let buttonStackView = UIStackView()
    
    /// 推奨アクション（やめる/ブロックするボタン）
    private let recommendedButton = UIButton(type: .system)
    
    /// 代替アクション（続行する/自己責任で開くボタン）
    private let alternativeButton = UIButton(type: .system)
    
    // MARK: - Initializer
    
    /**
     * イニシャライザ
     * @param url: 確認対象のURL
     * @param safetyLevel: 安全性レベル（caution または danger）
     */
    init(url: String, safetyLevel: SafetyLevel) {
        self.url = url
        self.safetyLevel = safetyLevel
        super.init(nibName: nil, bundle: nil)
        
        // モーダル表示の設定
        modalPresentationStyle = .overCurrentContext
        modalTransitionStyle = .crossDissolve
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureForSafetyLevel()
        setupAccessibility()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        animateIn()
    }
    
    // MARK: - UI Setup
    
    /**
     * UI要素の初期設定
     */
    private func setupUI() {
        view.backgroundColor = .clear
        setupBackgroundView()
        setupDialogContainer()
        setupWarningIcon()
        setupTitleLabel()
        setupUrlLabel()
        setupDescriptionLabel()
        setupAdviceLabel()
        setupButtons()
        setupConstraints()
    }
    
    /**
     * 背景ビューの設定（タップで閉じる機能付き）
     */
    private func setupBackgroundView() {
        backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundView)
        
        // 背景タップで閉じる
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        backgroundView.addGestureRecognizer(tapGesture)
    }
    
    /**
     * ダイアログコンテナの設定
     */
    private func setupDialogContainer() {
        dialogContainer.backgroundColor = .systemBackground
        dialogContainer.layer.cornerRadius = 16
        dialogContainer.layer.shadowColor = UIColor.black.cgColor
        dialogContainer.layer.shadowOpacity = 0.3
        dialogContainer.layer.shadowOffset = CGSize(width: 0, height: 8)
        dialogContainer.layer.shadowRadius = 16
        dialogContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dialogContainer)
    }
    
    /**
     * 警告アイコンの設定
     */
    private func setupWarningIcon() {
        warningIconLabel.textAlignment = .center
        warningIconLabel.font = UIFont.systemFont(ofSize: 48)
        warningIconLabel.translatesAutoresizingMaskIntoConstraints = false
        dialogContainer.addSubview(warningIconLabel)
    }
    
    /**
     * タイトルラベルの設定
     */
    private func setupTitleLabel() {
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Dynamic Type対応
        titleLabel.adjustsFontForContentSizeCategory = true
        
        dialogContainer.addSubview(titleLabel)
    }
    
    /**
     * URLラベルの設定
     */
    private func setupUrlLabel() {
        urlLabel.text = url
        urlLabel.textAlignment = .center
        urlLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        urlLabel.textColor = .secondaryLabel
        urlLabel.numberOfLines = 0
        urlLabel.lineBreakMode = .byCharWrapping // 長いURLを折り返し
        urlLabel.translatesAutoresizingMaskIntoConstraints = false
        urlLabel.adjustsFontForContentSizeCategory = true
        
        // URLをボックスで囲む
        urlLabel.backgroundColor = UIColor.systemGray6
        urlLabel.layer.cornerRadius = 8
        urlLabel.layer.masksToBounds = true
        urlLabel.textInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        
        dialogContainer.addSubview(urlLabel)
    }
    
    /**
     * 説明文ラベルの設定
     */
    private func setupDescriptionLabel() {
        descriptionLabel.textAlignment = .center
        descriptionLabel.font = UIFont.systemFont(ofSize: 16)
        descriptionLabel.textColor = .label
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.adjustsFontForContentSizeCategory = true
        
        dialogContainer.addSubview(descriptionLabel)
    }
    
    /**
     * アドバイスラベルの設定
     */
    private func setupAdviceLabel() {
        adviceLabel.textAlignment = .center
        adviceLabel.font = UIFont.systemFont(ofSize: 14)
        adviceLabel.textColor = .secondaryLabel
        adviceLabel.numberOfLines = 0
        adviceLabel.translatesAutoresizingMaskIntoConstraints = false
        adviceLabel.adjustsFontForContentSizeCategory = true
        
        dialogContainer.addSubview(adviceLabel)
    }
    
    /**
     * ボタンの設定
     */
    private func setupButtons() {
        setupButtonStackView()
        setupRecommendedButton()
        setupAlternativeButton()
    }
    
    /**
     * ボタンスタックビューの設定
     */
    private func setupButtonStackView() {
        buttonStackView.axis = .vertical
        buttonStackView.spacing = 12
        buttonStackView.distribution = .fillEqually
        buttonStackView.translatesAutoresizingMaskIntoConstraints = false
        dialogContainer.addSubview(buttonStackView)
    }
    
    /**
     * 推奨ボタン（安全な選択）の設定
     */
    private func setupRecommendedButton() {
        recommendedButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        recommendedButton.backgroundColor = .systemBlue
        recommendedButton.setTitleColor(.white, for: .normal)
        recommendedButton.layer.cornerRadius = 12
        recommendedButton.translatesAutoresizingMaskIntoConstraints = false
        
        // タップ領域を十分に確保
        recommendedButton.contentEdgeInsets = UIEdgeInsets(top: 16, left: 24, bottom: 16, right: 24)
        
        recommendedButton.addTarget(self, action: #selector(recommendedButtonTapped), for: .touchUpInside)
        buttonStackView.addArrangedSubview(recommendedButton)
    }
    
    /**
     * 代替ボタン（リスクを承知で続行）の設定
     */
    private func setupAlternativeButton() {
        alternativeButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        alternativeButton.backgroundColor = .clear
        alternativeButton.setTitleColor(.systemRed, for: .normal)
        alternativeButton.layer.borderColor = UIColor.systemRed.cgColor
        alternativeButton.layer.borderWidth = 1
        alternativeButton.layer.cornerRadius = 12
        alternativeButton.translatesAutoresizingMaskIntoConstraints = false
        
        alternativeButton.contentEdgeInsets = UIEdgeInsets(top: 16, left: 24, bottom: 16, right: 24)
        
        alternativeButton.addTarget(self, action: #selector(alternativeButtonTapped), for: .touchUpInside)
        buttonStackView.addArrangedSubview(alternativeButton)
    }
    
    /**
     * Auto Layout制約の設定
     */
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // 背景ビュー（全画面）
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // ダイアログコンテナ（中央配置）
            dialogContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            dialogContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            dialogContainer.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            dialogContainer.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            dialogContainer.widthAnchor.constraint(lessThanOrEqualToConstant: 400), // 最大幅制限
            
            // 警告アイコン
            warningIconLabel.topAnchor.constraint(equalTo: dialogContainer.topAnchor, constant: 24),
            warningIconLabel.centerXAnchor.constraint(equalTo: dialogContainer.centerXAnchor),
            
            // タイトルラベル
            titleLabel.topAnchor.constraint(equalTo: warningIconLabel.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: dialogContainer.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: dialogContainer.trailingAnchor, constant: -24),
            
            // URLラベル
            urlLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            urlLabel.leadingAnchor.constraint(equalTo: dialogContainer.leadingAnchor, constant: 24),
            urlLabel.trailingAnchor.constraint(equalTo: dialogContainer.trailingAnchor, constant: -24),
            
            // 説明文ラベル
            descriptionLabel.topAnchor.constraint(equalTo: urlLabel.bottomAnchor, constant: 16),
            descriptionLabel.leadingAnchor.constraint(equalTo: dialogContainer.leadingAnchor, constant: 24),
            descriptionLabel.trailingAnchor.constraint(equalTo: dialogContainer.trailingAnchor, constant: -24),
            
            // アドバイスラベル
            adviceLabel.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 12),
            adviceLabel.leadingAnchor.constraint(equalTo: dialogContainer.leadingAnchor, constant: 24),
            adviceLabel.trailingAnchor.constraint(equalTo: dialogContainer.trailingAnchor, constant: -24),
            
            // ボタンスタックビュー
            buttonStackView.topAnchor.constraint(equalTo: adviceLabel.bottomAnchor, constant: 24),
            buttonStackView.leadingAnchor.constraint(equalTo: dialogContainer.leadingAnchor, constant: 24),
            buttonStackView.trailingAnchor.constraint(equalTo: dialogContainer.trailingAnchor, constant: -24),
            buttonStackView.bottomAnchor.constraint(equalTo: dialogContainer.bottomAnchor, constant: -24),
            
            // ボタンの高さ制約
            recommendedButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),
            alternativeButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50)
        ])
    }
    
    /**
     * 安全性レベルに応じた表示内容の設定
     */
    private func configureForSafetyLevel() {
        switch safetyLevel {
        case .danger:
            configureDangerLevel()
        case .caution:
            configureCautionLevel()
        case .safe:
            // safeの場合はこのダイアログは表示されないはずだが、念のため
            configureSafeLevel()
        }
    }
    
    /**
     * 危険レベルの表示設定
     */
    private func configureDangerLevel() {
        warningIconLabel.text = "⚠️"
        warningIconLabel.textColor = .systemRed
        
        titleLabel.text = "危険な可能性があります"
        titleLabel.textColor = .systemRed
        
        descriptionLabel.text = "このリンクは危険な可能性が高いと判定されました。\\n詐欺サイトやマルウェアの感染リスクがあります。"
        
        adviceLabel.text = safetyLevel.recommendedAction
        
        // ボタンの設定（危険度が高いため、より強い表現）
        recommendedButton.setTitle("ブロックする（推奨）", for: .normal)
        recommendedButton.backgroundColor = .systemRed
        
        alternativeButton.setTitle("自己責任で開く", for: .normal)
        alternativeButton.setTitleColor(.systemRed, for: .normal)
    }
    
    /**
     * 注意レベルの表示設定
     */
    private func configureCautionLevel() {
        warningIconLabel.text = "⚠️"
        warningIconLabel.textColor = .systemOrange
        
        titleLabel.text = "不審な可能性があります"
        titleLabel.textColor = .systemOrange
        
        descriptionLabel.text = "このリンクには注意が必要です。\\n不審なサイトやフィッシングサイトの可能性があります。"
        
        adviceLabel.text = safetyLevel.recommendedAction
        
        // ボタンの設定（注意レベルなので、やや穏やかな表現）
        recommendedButton.setTitle("やめる（推奨）", for: .normal)
        recommendedButton.backgroundColor = .systemOrange
        
        alternativeButton.setTitle("続行する", for: .normal)
        alternativeButton.setTitleColor(.systemOrange, for: .normal)
        alternativeButton.layer.borderColor = UIColor.systemOrange.cgColor
    }
    
    /**
     * 安全レベルの表示設定（念のため）
     */
    private func configureSafeLevel() {
        warningIconLabel.text = "✅"
        warningIconLabel.textColor = .systemGreen
        
        titleLabel.text = "このリンクは安全です"
        titleLabel.textColor = .systemGreen
        
        descriptionLabel.text = "このリンクは安全と判定されました。"
        adviceLabel.text = ""
        
        recommendedButton.setTitle("開く", for: .normal)
        recommendedButton.backgroundColor = .systemGreen
        
        alternativeButton.setTitle("キャンセル", for: .normal)
        alternativeButton.setTitleColor(.systemGray, for: .normal)
        alternativeButton.layer.borderColor = UIColor.systemGray.cgColor
    }
    
    /**
     * アクセシビリティの設定
     */
    private func setupAccessibility() {
        // VoiceOver用の設定
        dialogContainer.isAccessibilityElement = false
        dialogContainer.accessibilityElements = [
            titleLabel,
            urlLabel, 
            descriptionLabel,
            adviceLabel,
            recommendedButton,
            alternativeButton
        ]
        
        // VoiceOver用のラベル設定
        titleLabel.accessibilityTraits = .header
        recommendedButton.accessibilityHint = "安全な選択です"
        alternativeButton.accessibilityHint = "リスクがあります"
        
        // 最初に読み上げる要素を設定
        UIAccessibility.post(notification: .screenChanged, argument: titleLabel)
    }
    
    // MARK: - Animation
    
    /**
     * ダイアログ表示アニメーション
     */
    private func animateIn() {
        // 初期状態
        backgroundView.alpha = 0
        dialogContainer.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        dialogContainer.alpha = 0
        
        // アニメーション実行
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut], animations: {
            self.backgroundView.alpha = 1
            self.dialogContainer.transform = .identity
            self.dialogContainer.alpha = 1
        })
    }
    
    /**
     * ダイアログ非表示アニメーション
     * @param completion: アニメーション完了時の処理
     */
    private func animateOut(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseIn], animations: {
            self.backgroundView.alpha = 0
            self.dialogContainer.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            self.dialogContainer.alpha = 0
        }) { _ in
            completion()
        }
    }
    
    // MARK: - Button Actions
    
    /**
     * 推奨ボタン（安全な選択）タップ処理
     */
    @objc private func recommendedButtonTapped() {
        // 安全な選択（URLを開かない）
        dismissWithDecision(shouldOpen: false)
    }
    
    /**
     * 代替ボタン（リスク承知で続行）タップ処理
     */
    @objc private func alternativeButtonTapped() {
        // リスクを承知でURLを開く
        dismissWithDecision(shouldOpen: true)
    }
    
    /**
     * 背景タップ処理
     */
    @objc private func backgroundTapped() {
        // 背景タップは安全な選択（URLを開かない）として扱う
        dismissWithDecision(shouldOpen: false)
    }
    
    /**
     * 決定結果とともにダイアログを閉じる
     * @param shouldOpen: URLを開くかどうか
     */
    private func dismissWithDecision(shouldOpen: Bool) {
        animateOut { [weak self] in
            self?.dismiss(animated: false) {
                // コールバックでScannerViewControllerに結果を通知
                self?.onUserDecision?(shouldOpen)
            }
        }
    }
}

// MARK: - UILabel Extension

/**
 * UILabel拡張：テキストインセット対応
 * URLラベルのボックス表示に使用
 */
extension UILabel {
    private struct AssociatedKeys {
        static var textInsets = "textInsets"
    }
    
    /// テキストインセット
    var textInsets: UIEdgeInsets {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.textInsets) as? UIEdgeInsets ?? .zero
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.textInsets, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            setNeedsDisplay()
        }
    }
    
    override open var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + textInsets.left + textInsets.right,
                     height: size.height + textInsets.top + textInsets.bottom)
    }
}