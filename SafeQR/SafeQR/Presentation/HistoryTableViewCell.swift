import UIKit

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

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
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
