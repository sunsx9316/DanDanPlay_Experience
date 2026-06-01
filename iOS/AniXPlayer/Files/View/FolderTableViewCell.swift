//
//  FolderTableViewCell.swift
//  Runner
//
//  Created by jimhuang on 2021/3/29.
//

import UIKit
import Kingfisher

class FolderTableViewCell: TableViewCell {

    lazy var imgView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    lazy var titleLabel: Label = {
        let label = Label()
        label.numberOfLines = 0
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    private lazy var coverBackgroundView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.alpha = 0.25
        iv.clipsToBounds = true
        iv.setContentCompressionResistancePriority(.fittingSizeLevel, for: .vertical)
        iv.setContentHuggingPriority(.fittingSizeLevel, for: .vertical)
        return iv
    }()

    var file: File? {
        didSet {
            self.titleLabel.text = self.file?.fileName
            if let coverURL = self.file?.coverImageURL {
                self.coverBackgroundView.kf.setImage(with: coverURL)
                self.coverBackgroundView.isHidden = false
            } else {
                self.coverBackgroundView.kf.cancelDownloadTask()
                self.coverBackgroundView.isHidden = true
                self.coverBackgroundView.image = nil
            }
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundView?.backgroundColor = .clear
        self.backgroundColor = .clear

        self.contentView.clipsToBounds = true
        self.contentView.insertSubview(self.coverBackgroundView, at: 0)
        contentView.addSubview(imgView)
        contentView.addSubview(titleLabel)

        imgView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.leading.equalToSuperview().offset(10)
            make.bottom.lessThanOrEqualToSuperview().offset(-10)
        }

        titleLabel.snp.makeConstraints { make in
            make.centerY.equalTo(imgView)
            make.top.equalTo(imgView)
            make.leading.equalTo(imgView.snp.trailing).offset(10)
            make.trailing.lessThanOrEqualToSuperview().offset(-10)
            make.bottom.lessThanOrEqualToSuperview().offset(-10)
        }

        self.titleLabel.textColor = .textColor
        self.titleLabel.font = .ddp_normal

        self.setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.coverBackgroundView.frame = self.contentView.bounds
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.setupUI()
    }

    private func setupUI() {
        self.imgView.image = UIImage(named: "Public/folder")?.byTintColor(.mainColor)
    }

}
