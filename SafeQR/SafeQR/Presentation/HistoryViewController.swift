import UIKit
import SafariServices

/**
 * スキャン履歴表示画面
 * - 最大50件の履歴を最新順で表示
 * - タイトル付きリスト（タイトル取得失敗時はドメインを表示）
 * - 安全性バッジ（SAFE/注意/危険）
 * - スワイプ削除、全削除機能
 * - 履歴項目タップで再度そのURLを開く
 */
class HistoryViewController: UIViewController {
    
    // MARK: - UI Components
    
    /// テーブルビュー（履歴リスト表示用）
    private let tableView = UITableView()
    
    /// 空状態を示すビュー
    private let emptyStateView = UIView()
    
    /// 空状態アイコンラベル
    private let emptyIconLabel = UILabel()
    
    /// 空状態メッセージラベル
    private let emptyMessageLabel = UILabel()
    
    /// 空状態説明ラベル
    private let emptyDescriptionLabel = UILabel()
    
    // MARK: - Data
    
    /// 履歴データ
    private var scanRecords: [ScanRecord] = []
    
    /// 履歴リポジトリ
    private let historyRepository = HistoryRepository()
    
    // MARK: - Constants
    
    /// セルの再利用識別子
    private static let cellIdentifier = "HistoryCell"
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        setupTableView()
        setupEmptyStateView()
        loadHistoryData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 画面表示時に履歴データを再読み込み（他画面で履歴が追加された可能性）
        loadHistoryData()
    }
    
    // MARK: - UI Setup
    
    /**
     * UI要素の基本設定
     */
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "履歴"
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
        
        // 編集ボタン（右上）
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "編集",
            style: .plain,
            target: self,
            action: #selector(editButtonTapped)
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
        tableView.register(HistoryTableViewCell.self, forCellReuseIdentifier: Self.cellIdentifier)
        
        // テーブルビューの外観設定
        tableView.backgroundColor = .systemBackground
        tableView.separatorStyle = .singleLine
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        
        // 空の行を非表示
        tableView.tableFooterView = UIView()
        
        view.addSubview(tableView)
        
        // Auto Layout設定
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    /**
     * 空状態ビューの設定
     */
    private func setupEmptyStateView() {
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.isHidden = true // 初期は非表示
        view.addSubview(emptyStateView)
        
        setupEmptyIconLabel()
        setupEmptyMessageLabel()
        setupEmptyDescriptionLabel()
        
        // Auto Layout設定
        NSLayoutConstraint.activate([
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            emptyStateView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40),
            
            emptyIconLabel.topAnchor.constraint(equalTo: emptyStateView.topAnchor),
            emptyIconLabel.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            
            emptyMessageLabel.topAnchor.constraint(equalTo: emptyIconLabel.bottomAnchor, constant: 16),
            emptyMessageLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor),
            emptyMessageLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor),
            
            emptyDescriptionLabel.topAnchor.constraint(equalTo: emptyMessageLabel.bottomAnchor, constant: 8),
            emptyDescriptionLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor),
            emptyDescriptionLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor),
            emptyDescriptionLabel.bottomAnchor.constraint(equalTo: emptyStateView.bottomAnchor)
        ])
    }
    
    /**
     * 空状態アイコンラベルの設定
     */
    private func setupEmptyIconLabel() {
        emptyIconLabel.text = "📝"
        emptyIconLabel.font = UIFont.systemFont(ofSize: 60)
        emptyIconLabel.textAlignment = .center
        emptyIconLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.addSubview(emptyIconLabel)
    }
    
    /**
     * 空状態メッセージラベルの設定
     */
    private func setupEmptyMessageLabel() {
        emptyMessageLabel.text = "まだ履歴はありません"
        emptyMessageLabel.font = UIFont.systemFont(ofSize: 20, weight: .medium)
        emptyMessageLabel.textColor = .label
        emptyMessageLabel.textAlignment = .center
        emptyMessageLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyMessageLabel.adjustsFontForContentSizeCategory = true
        emptyStateView.addSubview(emptyMessageLabel)
    }
    
    /**
     * 空状態説明ラベルの設定
     */
    private func setupEmptyDescriptionLabel() {
        emptyDescriptionLabel.text = "QRを読み取るとここに表示されます"
        emptyDescriptionLabel.font = UIFont.systemFont(ofSize: 16)
        emptyDescriptionLabel.textColor = .secondaryLabel
        emptyDescriptionLabel.textAlignment = .center
        emptyDescriptionLabel.numberOfLines = 0
        emptyDescriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyDescriptionLabel.adjustsFontForContentSizeCategory = true
        emptyStateView.addSubview(emptyDescriptionLabel)
    }
    
    // MARK: - Data Loading
    
    /**
     * 履歴データの読み込み
     */
    private func loadHistoryData() {
        scanRecords = (try? historyRepository.getAllRecords()) ?? []
        
        DispatchQueue.main.async { [weak self] in
            self?.updateUI()
        }
    }
    
    /**
     * UI状態の更新
     */
    private func updateUI() {
        tableView.reloadData()
        
        // 空状態の表示制御
        let isEmpty = scanRecords.isEmpty
        emptyStateView.isHidden = !isEmpty
        tableView.isHidden = isEmpty
        
        // ナビゲーションバーのボタン状態更新
        navigationItem.rightBarButtonItem?.isEnabled = !isEmpty
    }
    
    // MARK: - Navigation Actions
    
    /**
     * 閉じるボタンタップ処理
     */
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    /**
     * 編集ボタンタップ処理
     */
    @objc private func editButtonTapped() {
        let isEditing = tableView.isEditing
        
        // 編集モードの切り替え
        tableView.setEditing(!isEditing, animated: true)
        
        // ボタンテキストの更新
        navigationItem.rightBarButtonItem?.title = isEditing ? "編集" : "完了"
        
        // 編集モード時は全削除ボタンを追加
        if !isEditing {
            // 編集モード開始時
            let deleteAllButton = UIBarButtonItem(
                title: "すべて削除",
                style: .plain,
                target: self,
                action: #selector(deleteAllButtonTapped)
            )
            deleteAllButton.tintColor = .systemRed
            
            navigationItem.leftBarButtonItems = [
                navigationItem.leftBarButtonItem!, // 既存の閉じるボタン
                deleteAllButton
            ]
        } else {
            // 編集モード終了時
            navigationItem.leftBarButtonItems = [navigationItem.leftBarButtonItem!]
        }
    }
    
    /**
     * すべて削除ボタンタップ処理
     */
    @objc private func deleteAllButtonTapped() {
        // 確認アラート表示
        let alert = UIAlertController(
            title: "すべて削除",
            message: "すべての履歴を削除しますか？\\nこの操作は取り消せません。",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        alert.addAction(UIAlertAction(title: "削除", style: .destructive) { [weak self] _ in
            self?.deleteAllHistory()
        })
        
        present(alert, animated: true)
    }
    
    /**
     * 全履歴削除処理
     */
    private func deleteAllHistory() {
        historyRepository.deleteAllScanRecords()
        scanRecords.removeAll()
        
        // 編集モード終了
        tableView.setEditing(false, animated: true)
        navigationItem.rightBarButtonItem?.title = "編集"
        navigationItem.leftBarButtonItems = [navigationItem.leftBarButtonItem!]
        
        updateUI()
        
        // 削除完了のフィードバック
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    // MARK: - Helper Methods
    
    /**
     * 個別履歴削除処理
     * @param indexPath: 削除する履歴のインデックス
     */
    private func deleteHistory(at indexPath: IndexPath) {
        let scanRecord = scanRecords[indexPath.row]
        
        // リポジトリから削除
        historyRepository.deleteScanRecord(by: scanRecord.id)
        
        // ローカル配列から削除
        scanRecords.remove(at: indexPath.row)
        
        // テーブルビューから削除（アニメーション付き）
        tableView.deleteRows(at: [indexPath], with: .fade)
        
        // 全て削除された場合の空状態表示
        if scanRecords.isEmpty {
            updateUI()
        }
        
        // 削除フィードバック
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    /**
     * 履歴項目タップ時の処理（URLを再度開く）
     * @param scanRecord: タップされた履歴レコード
     */
    private func openURL(from scanRecord: ScanRecord) {
        guard let url = URL(string: scanRecord.url) else {
            showErrorAlert("無効なURLです")
            return
        }
        
        // SFSafariViewControllerで開く
        let safariVC = SFSafariViewController(url: url)
        safariVC.modalPresentationStyle = .pageSheet
        present(safariVC, animated: true)
        
        // 履歴の訪問回数を更新（バックグラウンド処理）
        DispatchQueue.global().async { [weak self] in
            var updatedRecord = scanRecord
            updatedRecord.visitCount += 1
            self?.historyRepository.upsertScanRecord(updatedRecord)
            
            // UI更新
            DispatchQueue.main.async {
                self?.loadHistoryData()
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

// MARK: - UITableViewDataSource

extension HistoryViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return scanRecords.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: Self.cellIdentifier,
            for: indexPath
        ) as? HistoryTableViewCell else {
            return UITableViewCell()
        }
        
        let scanRecord = scanRecords[indexPath.row]
        cell.configure(with: scanRecord)
        
        return cell
    }
}

// MARK: - UITableViewDelegate

extension HistoryViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let scanRecord = scanRecords[indexPath.row]
        openURL(from: scanRecord)
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            deleteHistory(at: indexPath)
        }
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        return "削除"
    }
}

// MARK: - HistoryTableViewCell

/**
 * 履歴表示用カスタムテーブルビューセル
 * タイトル、URL（ドメイン）、安全性バッジ、訪問回数を表示
 */
class HistoryTableViewCell: UITableViewCell {
    
    // MARK: - UI Components
    
    /// タイトルラベル（太字、メイン表示）
    private let titleLabel = UILabel()
    
    /// URLラベル（ドメイン表示、グレー）
    private let urlLabel = UILabel()
    
    /// 日時ラベル
    private let dateLabel = UILabel()
    
    /// 安全性バッジ
    private let safetyBadge = UILabel()
    
    /// 訪問回数ラベル
    private let visitCountLabel = UILabel()
    
    /// ファビコン表示用イメージビュー（将来の機能拡張用）
    private let faviconImageView = UIImageView()
    
    // MARK: - Initialization
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    
    /**
     * セルのUI設定
     */
    private func setupUI() {
        setupTitleLabel()
        setupUrlLabel()
        setupDateLabel()
        setupSafetyBadge()
        setupVisitCountLabel()
        setupFaviconImageView()
        setupConstraints()
        
        // セルの外観設定
        accessoryType = .disclosureIndicator
        selectionStyle = .default
    }
    
    private func setupTitleLabel() {
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.adjustsFontForContentSizeCategory = true
        contentView.addSubview(titleLabel)
    }
    
    private func setupUrlLabel() {
        urlLabel.font = UIFont.systemFont(ofSize: 14)
        urlLabel.textColor = .secondaryLabel
        urlLabel.numberOfLines = 1
        urlLabel.translatesAutoresizingMaskIntoConstraints = false
        urlLabel.adjustsFontForContentSizeCategory = true
        contentView.addSubview(urlLabel)
    }
    
    private func setupDateLabel() {
        dateLabel.font = UIFont.systemFont(ofSize: 12)
        dateLabel.textColor = .tertiaryLabel
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.adjustsFontForContentSizeCategory = true
        contentView.addSubview(dateLabel)
    }
    
    private func setupSafetyBadge() {
        safetyBadge.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        safetyBadge.textAlignment = .center
        safetyBadge.layer.cornerRadius = 8
        safetyBadge.layer.masksToBounds = true
        safetyBadge.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(safetyBadge)
    }
    
    private func setupVisitCountLabel() {
        visitCountLabel.font = UIFont.systemFont(ofSize: 12)
        visitCountLabel.textColor = .secondaryLabel
        visitCountLabel.translatesAutoresizingMaskIntoConstraints = false
        visitCountLabel.adjustsFontForContentSizeCategory = true
        contentView.addSubview(visitCountLabel)
    }
    
    private func setupFaviconImageView() {
        faviconImageView.contentMode = .scaleAspectFit
        faviconImageView.layer.cornerRadius = 4
        faviconImageView.layer.masksToBounds = true
        faviconImageView.backgroundColor = .systemGray6
        faviconImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(faviconImageView)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // ファビコン
            faviconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            faviconImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            faviconImageView.widthAnchor.constraint(equalToConstant: 32),
            faviconImageView.heightAnchor.constraint(equalToConstant: 32),
            
            // タイトル
            titleLabel.leadingAnchor.constraint(equalTo: faviconImageView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: safetyBadge.leadingAnchor, constant: -8),
            
            // URL
            urlLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            urlLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            urlLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            
            // 日時・訪問回数
            dateLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            dateLabel.topAnchor.constraint(equalTo: urlLabel.bottomAnchor, constant: 4),
            dateLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            visitCountLabel.leadingAnchor.constraint(equalTo: dateLabel.trailingAnchor, constant: 12),
            visitCountLabel.centerYAnchor.constraint(equalTo: dateLabel.centerYAnchor),
            
            // 安全性バッジ
            safetyBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            safetyBadge.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            safetyBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            safetyBadge.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    // MARK: - Configuration
    
    /**
     * セルの内容設定
     * @param scanRecord: 表示するスキャンレコード
     */
    func configure(with scanRecord: ScanRecord) {
        // タイトル設定（タイトル取得済みならそれを、なければドメインを表示）
        titleLabel.text = scanRecord.displayTitle
        
        // URL（ドメイン部分のみ）設定
        urlLabel.text = ScanRecord.extractDomain(from: scanRecord.url)
        
        // 日時設定
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        dateLabel.text = formatter.string(from: scanRecord.scannedAt)
        
        // 訪問回数設定
        if scanRecord.visitCount > 1 {
            visitCountLabel.text = "\(scanRecord.visitCount)回"
            visitCountLabel.isHidden = false
        } else {
            visitCountLabel.isHidden = true
        }
        
        // 安全性バッジ設定
        configureSafetyBadge(for: scanRecord.safety)
        
        // ファビコン設定（現在はプレースホルダー）
        configureFavicon(with: scanRecord.favicon)
    }
    
    /**
     * 安全性バッジの設定
     * @param safetyLevel: 安全性レベル
     */
    private func configureSafetyBadge(for safetyLevel: SafetyLevel) {
        switch safetyLevel {
        case .safe:
            safetyBadge.text = "SAFE"
            safetyBadge.backgroundColor = .systemGreen
            safetyBadge.textColor = .white
        case .caution:
            safetyBadge.text = "注意"
            safetyBadge.backgroundColor = .systemOrange
            safetyBadge.textColor = .white
        case .danger:
            safetyBadge.text = "危険"
            safetyBadge.backgroundColor = .systemRed
            safetyBadge.textColor = .white
        }
    }
    
    /**
     * ファビコンの設定
     * @param faviconData: ファビコンのバイナリデータ（現在は未実装）
     */
    private func configureFavicon(with faviconData: Data?) {
        if let data = faviconData, let image = UIImage(data: data) {
            faviconImageView.image = image
        } else {
            // プレースホルダー画像
            faviconImageView.image = UIImage(systemName: "globe")
            faviconImageView.tintColor = .systemGray
        }
    }
}
