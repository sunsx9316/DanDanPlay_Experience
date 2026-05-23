//
//  FolderProgressCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/5/23.
//

import UIKit
import SnapKit

class FolderProgressCell: TableViewCell {

    private lazy var iconView: UIImageView = {
        let imgView = UIImageView()
        imgView.image = .init(named: "Public/folder")?.byTintColor(.mainColor)
        return imgView
    }()

    private lazy var titleLabel: Label = {
        let label = Label()
        label.font = .ddp_normal
        label.numberOfLines = 0
        return label
    }()

    private lazy var progressLabel: Label = {
        let label = Label()
        label.font = .ddp_small
        label.textColor = .subtitleTextColor
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.contentView.addSubview(self.iconView)
        self.contentView.addSubview(self.titleLabel)
        self.contentView.addSubview(self.progressLabel)

        self.iconView.snp.makeConstraints { make in
            make.top.leading.equalTo(10)
            make.width.height.equalTo(50)
            make.bottom.lessThanOrEqualTo(-10)
        }

        self.titleLabel.snp.makeConstraints { make in
            make.top.equalTo(self.iconView.snp.top).offset(2)
            make.leading.equalTo(self.iconView.snp.trailing).offset(10)
            make.trailing.equalTo(-10)
        }

        self.progressLabel.snp.makeConstraints { make in
            make.top.equalTo(self.titleLabel.snp.bottom).offset(4)
            make.leading.equalTo(self.titleLabel)
            make.trailing.equalTo(-10)
            make.bottom.lessThanOrEqualTo(-10)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(folderName: String, completed: Int, total: Int?) {
        self.titleLabel.text = folderName + "/"
        if let total = total {
            self.progressLabel.text = "\(completed)/\(total)"
        } else {
            self.progressLabel.text = "\(completed) 个文件"
        }
    }
}
