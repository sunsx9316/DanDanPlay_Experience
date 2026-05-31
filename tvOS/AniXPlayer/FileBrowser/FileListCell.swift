//
//  FileListCell.swift
//  AniXPlayer
//
//  tvOS 文件列表 Cell
//

import UIKit
import SnapKit

class FileListCell: TableViewCell {

    static let reuseIdentifier = "FileListCell"

    private lazy var iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .label
        return iv
    }()

    private lazy var titleLabel: Label = {
        let label = Label()
        label.font = .ddp_normal(weight: .medium)
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()

    private lazy var detailLabel: Label = {
        let label = Label()
        label.font = .ddp_small()
        label.textColor = .secondaryLabel
        return label
    }()

    private lazy var textStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        return stack
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        contentView.addSubview(iconImageView)
        contentView.addSubview(textStack)

        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalToSuperview().offset(16)
            make.size.equalTo(CGSize(width: 48, height: 48))
        }

        textStack.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.top.equalToSuperview().offset(16)
            make.bottom.equalToSuperview().offset(-16).priority(.high)
        }
    }

    func configureAsSource(title: String, iconName: String, detail: String? = nil) {
        titleLabel.text = title
        if let detail = detail, !detail.isEmpty {
            detailLabel.text = detail
            detailLabel.isHidden = false
        } else {
            detailLabel.isHidden = true
        }
        iconImageView.image = UIImage(systemName: iconName)
    }

    func configure(with file: File) {
        titleLabel.text = file.fileName
        titleLabel.textColor = .label
        iconImageView.image = UIImage(systemName: file.type == .folder ? "folder" : "play.rectangle")
        iconImageView.tintColor = .label

        if file.type == .folder {
            detailLabel.isHidden = true
        } else {
            detailLabel.isHidden = false
            let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(file.fileSize), countStyle: .file)
            detailLabel.text = "\(sizeStr)  \(file.pathExtension.uppercased())"
        }
    }

    func configureAsHighlighted() {
        iconImageView.tintColor = .systemBlue
        titleLabel.textColor = .systemBlue
    }
}
