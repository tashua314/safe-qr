import UIKit

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

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
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

/*
 * セグメンテッドコントロール付きテーブルビューセル
 * 複数選択肢から1つを選ぶ設定項目用
 */
