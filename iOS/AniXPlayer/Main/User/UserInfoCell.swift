//
//  UserInfoCell.swift
//  AniXPlayer
//
//  用户信息 Cell — 头像 + 用户名
//

import UIKit
import SnapKit
import Kingfisher

class UserInfoCell: TableViewCell {

    private lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 40
        imageView.clipsToBounds = true
        imageView.layer.borderWidth = 2
        imageView.layer.borderColor = UIColor.mainColor.cgColor
        return imageView
    }()

    private lazy var usernameLabel: Label = {
        let label = Label()
        label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        label.numberOfLines = 0
        return label
    }()

    private lazy var separatorLine: UIView = {
        let view = UIView()
        view.backgroundColor = .separator
        return view
    }()

    var showSeparator: Bool = true {
        didSet {
            separatorLine.isHidden = !showSeparator
        }
    }

    func configure(avatarURL: URL?, username: String?) {
        if let url = avatarURL {
            avatarImageView.kf.setImage(with: url, placeholder: UIImage.placeholder)
        } else {
            avatarImageView.image = UIImage.placeholder
        }
        usernameLabel.text = username
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(avatarImageView)
        contentView.addSubview(usernameLabel)
        contentView.addSubview(separatorLine)

        avatarImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(80)
        }
        usernameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarImageView.snp.trailing).offset(16)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview().offset(-20)
        }
        separatorLine.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(1)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
