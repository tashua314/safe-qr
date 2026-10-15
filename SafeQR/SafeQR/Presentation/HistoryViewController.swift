import SafariServices
import UIKit

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
                navigationItem.leftBarButtonItem, // 既存の閉じるボタン
                deleteAllButton
            ].compactMap { $0 }
        } else {
            // 編集モード終了時
            navigationItem.leftBarButtonItems = [navigationItem.leftBarButtonItem].compactMap { $0 }
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
        navigationItem.leftBarButtonItems = [navigationItem.leftBarButtonItem].compactMap { $0 }

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
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
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

    func tableView(_: UITableView, canEditRowAt _: IndexPath) -> Bool {
        return true
    }

    func tableView(_: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            deleteHistory(at: indexPath)
        }
    }

    func tableView(_: UITableView, editingStyleForRowAt _: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }

    func tableView(_: UITableView, titleForDeleteConfirmationButtonForRowAt _: IndexPath) -> String? {
        return "削除"
    }
}

// MARK: - HistoryTableViewCell

/*
 * 履歴表示用カスタムテーブルビューセル
 * タイトル、URL（ドメイン）、安全性バッジ、訪問回数を表示
 */
