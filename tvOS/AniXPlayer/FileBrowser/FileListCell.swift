//
//  FileListCell.swift
//  AniXPlayer
//
//  tvOS 文件列表 Cell
//

import UIKit
import SnapKit
import Kingfisher

class FileListCell: TableViewCell {

    static let reuseIdentifier = "FileListCell"

    private lazy var coverImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.alpha = 0.25
        iv.clipsToBounds = true
        return iv
    }()

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
        label.textColor = .label
        label.numberOfLines = 0
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
        contentView.addSubview(coverImageView)
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
            make.bottom.equalToSuperview().offset(-16)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        coverImageView.frame = contentView.bounds
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        coverImageView.kf.cancelDownloadTask()
        coverImageView.image = nil
    }

    func configureAsSource(title: String, iconName: String, detail: String? = nil) {
        coverImageView.isHidden = true
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

        if let coverURL = file.coverImageURL {
            coverImageView.isHidden = false
            coverImageView.kf.setImage(with: coverURL, placeholder: UIImage.placeholder)
        } else {
            coverImageView.isHidden = true
            coverImageView.kf.cancelDownloadTask()
            coverImageView.image = nil
        }

        if file.type == .folder {
            detailLabel.isHidden = true
        } else {
            detailLabel.isHidden = false
            if file.fileSize > 0 {
                let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(file.fileSize), countStyle: .file)
                var detail = "\(sizeStr)  \(file.pathExtension.uppercased())"
                if let sourceName = file.sourceFileName {
                    detail += "\n\(sourceName)"
                }
                detailLabel.text = detail
            } else {
                var detail = file.pathExtension.uppercased()
                if let sourceName = file.sourceFileName {
                    detail = sourceName
                }
                detailLabel.text = detail
            }
        }
    }

    func configureAsHighlighted() {
        iconImageView.tintColor = .systemBlue
        titleLabel.textColor = .systemBlue
    }
}
