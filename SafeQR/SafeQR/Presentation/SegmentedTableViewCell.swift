import UIKit

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

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
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
