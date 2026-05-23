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
        label.font = .systemFont(ofSize: 20, weight: .medium)
        label.textColor = .label
        return label
    }()

    private lazy var detailLabel: Label = {
        let label = Label()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        return label
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
        contentView.addSubview(titleLabel)
        contentView.addSubview(detailLabel)

        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
            make.size.equalTo(CGSize(width: 40, height: 40))
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(16)
            make.trailing.equalToSuperview().offset(-20)
            make.top.equalToSuperview().offset(14)
        }

        detailLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
        }
    }

    func configureAsSource(title: String, iconName: String) {
        titleLabel.text = title
        detailLabel.text = nil
        iconImageView.image = UIImage(systemName: iconName)
    }

    func configure(with file: File) {
        titleLabel.text = file.fileName
        iconImageView.image = UIImage(systemName: file.type == .folder ? "folder" : "play.rectangle")

        if file.type == .folder {
            detailLabel.text = nil
        } else {
            let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(file.fileSize), countStyle: .file)
            detailLabel.text = "\(sizeStr)  \(file.pathExtension.uppercased())"
        }
    }
}
