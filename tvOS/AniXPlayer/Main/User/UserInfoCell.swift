//
//  UserInfoCell.swift
//  AniXPlayer
//
//  tvOS 用户信息 Cell — 头像 + 用户名，水平 stackView 布局
//

import UIKit
import SnapKit
import Kingfisher

class UserInfoCell: TableViewCell {

    static let reuseIdentifier = "UserInfoCell"

    private lazy var avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.layer.cornerRadius = 40
        iv.clipsToBounds = true
        iv.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        return iv
    }()

    private lazy var usernameLabel: UILabel = {
        let label = UILabel()
        label.font = .ddp_normal(weight: .bold)
        label.textColor = .label
        return label
    }()

    private lazy var stackView: UIStackView = {
        let sv = UIStackView(arrangedSubviews: [avatarImageView, usernameLabel])
        sv.axis = .horizontal
        sv.alignment = .center
        sv.spacing = 20
        return sv
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(stackView)
        avatarImageView.snp.makeConstraints { make in
            make.width.height.equalTo(80)
        }
        stackView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(40)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview().offset(-40)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(avatarURL: URL?, username: String) {
        usernameLabel.text = username
        if let url = avatarURL {
            avatarImageView.kf.setImage(with: url, placeholder: UIImage.placeholder)
            avatarImageView.isHidden = false
        } else {
            avatarImageView.kf.cancelDownloadTask()
            avatarImageView.image = nil
            avatarImageView.isHidden = true
        }
    }
}
