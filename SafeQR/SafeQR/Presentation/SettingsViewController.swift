import UIKit

/**
 * 設定画面
 * - 安全確認の厳しさ設定（弱・標準・強）
 * - 外部レピュテーション照会のON/OFF
 * - 履歴管理について（最大50件の説明）
 * - アプリ情報表示
 * ITリテラシーが低いユーザーでも理解しやすい説明文付き
 */
class SettingsViewController: UIViewController {
    
    // MARK: - UI Components
    
    /// メインのテーブルビュー
    private let tableView = UITableView(frame: .zero, style: .grouped)
    
    // MARK: - Data
    
    /// 設定ストア
    private let settingsStore = SettingsStore.shared
    
    /// テーブルビューのセクション定義
    private enum Section: Int, CaseIterable {
        case safety = 0      // 安全設定
        case privacy = 1     // プライバシー設定
        case history = 2     // 履歴設定
        case app = 3         // アプリ情報
        
        var title: String {
            switch self {
            case .safety:
                return "安全設定"
            case .privacy:
                return "プライバシー設定"
            case .history:
                return "履歴設定"
            case .app:
                return "アプリ情報"
            }
        }
        
        var footer: String? {
            switch self {
            case .safety:
                return "危険なサイトの検出レベルを調整できます。「強」にするとより多くのサイトで警告が表示されます。"
            case .privacy:
                return "個人情報は一切収集しません。URLの内容も外部に送信されません。"
            case .history:
                return "履歴は端末内にのみ保存され、最大50件まで記録されます。51件目以降は古いものから削除されます。"
            case .app:
                return nil
            }
        }
    }
    
    /// セルの種類定義
    private enum CellType {
        case safetyStrictness    // 厳しさ設定
        case externalReputation  // 外部照会設定
        case historyInfo        // 履歴情報
        case appVersion         // アプリバージョン
        case appInfo           // アプリ情報
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        setupTableView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 設定値の変更を反映
        tableView.reloadData()
    }
    
    // MARK: - UI Setup
    
    /**
     * UI要素の基本設定
     */
    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        title = "設定"
    }
    
    /**
     * ナビゲーションバーの設定
     */
    private func setupNavigationBar() {
        // 閉じるボタン（左上）
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "閉じる",
            style: .plain,
            target: self,
            action: #selector(closeButtonTapped)
        )
        
        // ナビゲーションバーを大きなタイトル表示に設定
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
    }
    
    /**
     * テーブルビューの設定
     */
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        // セルの登録
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DefaultCell")
        tableView.register(SwitchTableViewCell.self, forCellReuseIdentifier: "SwitchCell")
        tableView.register(SegmentedTableViewCell.self, forCellReuseIdentifier: "SegmentedCell")
        
        // テーブルビューの外観設定
        tableView.backgroundColor = .systemGroupedBackground
        
        view.addSubview(tableView)
        
        // Auto Layout設定
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - Navigation Actions
    
    /**
     * 閉じるボタンタップ処理
     */
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    // MARK: - Helper Methods
    
    /**
     * セクションのセル種類を取得
     * @param section: セクション番号
     * @param row: 行番号
     * @return: セルの種類
     */
    private func getCellType(for section: Int, row: Int) -> CellType {
        guard let sectionType = Section(rawValue: section) else {
            return .appInfo
        }
        
        switch sectionType {
        case .safety:
            return .safetyStrictness
        case .privacy:
            return .externalReputation
        case .history:
            return .historyInfo
        case .app:
            return row == 0 ? .appVersion : .appInfo
        }
    }
    
    /**
     * アプリバージョン情報を取得
     * @return: バージョン文字列
     */
    private func getAppVersion() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "バージョン \(version) (ビルド \(build))"
    }
}

// MARK: - UITableViewDataSource

extension SettingsViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionType = Section(rawValue: section) else { return 0 }
        
        switch sectionType {
        case .safety, .privacy, .history:
            return 1
        case .app:
            return 2 // バージョン情報 + アプリ情報
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Section(rawValue: section)?.title
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return Section(rawValue: section)?.footer
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellType = getCellType(for: indexPath.section, row: indexPath.row)
        
        switch cellType {
        case .safetyStrictness:
            return configureSafetyStrictnessCell(at: indexPath)
        case .externalReputation:
            return configureExternalReputationCell(at: indexPath)
        case .historyInfo:
            return configureHistoryInfoCell(at: indexPath)
        case .appVersion:
            return configureAppVersionCell(at: indexPath)
        case .appInfo:
            return configureAppInfoCell(at: indexPath)
        }
    }
    
    /**
     * 厳しさ設定セルの構成
     */
    private func configureSafetyStrictnessCell(at indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: "SegmentedCell",
            for: indexPath
        ) as? SegmentedTableViewCell else {
            return UITableViewCell()
        }
        
        let currentStrictness = settingsStore.safetyStrictness
        let options = SafetyStrictness.allCases.map { $0.displayName }
        let selectedIndex = SafetyStrictness.allCases.firstIndex(of: currentStrictness) ?? 1
        
        cell.configure(
            title: "安全確認の厳しさ",
            options: options,
            selectedIndex: selectedIndex
        ) { [weak self] selectedIndex in
            // 選択変更時の処理
            if selectedIndex < SafetyStrictness.allCases.count {
                let newStrictness = SafetyStrictness.allCases[selectedIndex]
                self?.settingsStore.safetyStrictness = newStrictness
            }
        }
        
        return cell
    }
    
    /**
     * 外部レピュテーション設定セルの構成
     */
    private func configureExternalReputationCell(at indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: "SwitchCell",
            for: indexPath
        ) as? SwitchTableViewCell else {
            return UITableViewCell()
        }
        
        cell.configure(
            title: "外部安全性チェック",
            subtitle: "Google脅威データベースでより正確に判定",
            isOn: settingsStore.isExternalReputationEnabled
        ) { [weak self] isOn in
            // スイッチ変更時の処理
            self?.settingsStore.isExternalReputationEnabled = isOn
        }
        
        return cell
    }
    
    /**
     * 履歴情報セルの構成
     */
    private func configureHistoryInfoCell(at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DefaultCell", for: indexPath)
        
        cell.textLabel?.text = "履歴の保存"
        cell.detailTextLabel?.text = "最大50件（端末内のみ）"
        cell.selectionStyle = .none
        cell.accessoryType = .none
        
        // アイコン設定
        cell.imageView?.image = UIImage(systemName: "clock")
        cell.imageView?.tintColor = .systemBlue
        
        return cell
    }
    
    /**
     * アプリバージョンセルの構成
     */
    private func configureAppVersionCell(at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DefaultCell", for: indexPath)
        
        cell.textLabel?.text = "SafeQR"
        cell.detailTextLabel?.text = getAppVersion()
        cell.selectionStyle = .none
        cell.accessoryType = .none
        
        // アプリアイコン設定（システムアイコンで代用）
        cell.imageView?.image = UIImage(systemName: "qrcode.viewfinder")
        cell.imageView?.tintColor = .systemGreen
        
        return cell
    }
    
    /**
     * アプリ情報セルの構成
     */
    private func configureAppInfoCell(at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DefaultCell", for: indexPath)
        
        cell.textLabel?.text = "開発情報"
        cell.detailTextLabel?.text = "安全なQRコードリーダー"
        cell.selectionStyle = .default
        cell.accessoryType = .disclosureIndicator
        
        // 情報アイコン設定
        cell.imageView?.image = UIImage(systemName: "info.circle")
        cell.imageView?.tintColor = .systemBlue
        
        return cell
    }
}

// MARK: - UITableViewDelegate

extension SettingsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let cellType = getCellType(for: indexPath.section, row: indexPath.row)
        
        switch cellType {
        case .appInfo:
            showAppInfoAlert()
        default:
            break
        }
    }
    
    /**
     * アプリ情報アラートの表示
     */
    private func showAppInfoAlert() {
        let alert = UIAlertController(
            title: "SafeQR について",
            message: """
            SafeQRは、ITリテラシーが低い方でも安全にQRコードを利用できることを目指したアプリです。
            
            【主な機能】
            • QRコードの安全性自動判定
            • 危険なサイトからの保護
            • 履歴管理（端末内のみ）
            • プライバシー重視設計
            
            ご利用いただきありがとうございます。
            """,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - SwitchTableViewCell

/**
 * スイッチ付きテーブルビューセル
 * ON/OFF切り替えが可能な設定項目用
 */
class SwitchTableViewCell: UITableViewCell {
    
    // MARK: - UI Components
    
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let switchControl = UISwitch()
    
    // MARK: - Properties
    
    /// スイッチ変更時のコールバック
    private var onSwitchChanged: ((Bool) -> Void)?
    
    // MARK: - Initialization
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        selectionStyle = .none
        
        setupTitleLabel()
        setupSubtitleLabel()
        setupSwitchControl()
        setupConstraints()
    }
    
    private func setupTitleLabel() {
        titleLabel.font = UIFont.systemFont(ofSize: 16)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.adjustsFontForContentSizeCategory = true
        contentView.addSubview(titleLabel)
    }
    
    private func setupSubtitleLabel() {
        subtitleLabel.font = UIFont.systemFont(ofSize: 14)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.adjustsFontForContentSizeCategory = true
        contentView.addSubview(subtitleLabel)
    }
    
    private func setupSwitchControl() {
        switchControl.translatesAutoresizingMaskIntoConstraints = false
        switchControl.addTarget(self, action: #selector(switchValueChanged), for: .valueChanged)
        contentView.addSubview(switchControl)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: switchControl.leadingAnchor, constant: -16),
            
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            
            switchControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            switchControl.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    // MARK: - Configuration
    
    /**
     * セルの設定
     * @param title: メインタイトル
     * @param subtitle: サブタイトル
     * @param isOn: スイッチの初期状態
     * @param onSwitchChanged: スイッチ変更時のコールバック
     */
    func configure(title: String, subtitle: String?, isOn: Bool, onSwitchChanged: @escaping (Bool) -> Void) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        subtitleLabel.isHidden = subtitle == nil
        switchControl.isOn = isOn
        self.onSwitchChanged = onSwitchChanged
    }
    
    // MARK: - Actions
    
    @objc private func switchValueChanged() {
        onSwitchChanged?(switchControl.isOn)
    }
}

// MARK: - SegmentedTableViewCell

/**
 * セグメンテッドコントロール付きテーブルビューセル
 * 複数選択肢から1つを選ぶ設定項目用
 */
class SegmentedTableViewCell: UITableViewCell {
    
    // MARK: - UI Components
    
    private let titleLabel = UILabel()
    private let segmentedControl = UISegmentedControl()
    
    // MARK: - Properties
    
    /// 選択変更時のコールバック
    private var onSelectionChanged: ((Int) -> Void)?
    
    // MARK: - Initialization
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        selectionStyle = .none
        
        setupTitleLabel()
        setupSegmentedControl()
        setupConstraints()
    }
    
    private func setupTitleLabel() {
        titleLabel.font = UIFont.systemFont(ofSize: 16)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.adjustsFontForContentSizeCategory = true
        contentView.addSubview(titleLabel)
    }
    
    private func setupSegmentedControl() {
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        contentView.addSubview(segmentedControl)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            segmentedControl.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            segmentedControl.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            segmentedControl.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            segmentedControl.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            segmentedControl.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    // MARK: - Configuration
    
    /**
     * セルの設定
     * @param title: タイトル
     * @param options: 選択肢の配列
     * @param selectedIndex: 初期選択インデックス
     * @param onSelectionChanged: 選択変更時のコールバック
     */
    func configure(title: String, options: [String], selectedIndex: Int, onSelectionChanged: @escaping (Int) -> Void) {
        titleLabel.text = title
        
        // セグメンテッドコントロールの設定
        segmentedControl.removeAllSegments()
        for (index, option) in options.enumerated() {
            segmentedControl.insertSegment(withTitle: option, at: index, animated: false)
        }
        segmentedControl.selectedSegmentIndex = selectedIndex
        
        self.onSelectionChanged = onSelectionChanged
    }
    
    // MARK: - Actions
    
    @objc private func segmentChanged() {
        onSelectionChanged?(segmentedControl.selectedSegmentIndex)
    }
}