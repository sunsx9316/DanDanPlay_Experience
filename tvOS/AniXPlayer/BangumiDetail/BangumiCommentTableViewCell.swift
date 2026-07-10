//
//  BangumiCommentTableViewCell.swift
//  AniXPlayer
//
//  tvOS 短评论 Cell — 头像 + 用户名 + 评分 + 来源 + 内容 + 时间
//

import UIKit
import Kingfisher

class BangumiCommentTableViewCell: TableViewCell {

    private let avatarSize = CGSize(width: 36, height: 36)

    private lazy var avatarImageView: ImageView = {
        let iv = ImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = avatarSize.width / 2
        iv.adjustsImageWhenAncestorFocused = true
        return iv
    }()

    private lazy var userNameLabel: Label = {
        let label = Label()
        label.font = .ddp_normal(weight: .bold)
        label.textColor = .label
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    private lazy var ratingLabel: Label = {
        let label = Label()
        label.font = .ddp_small(weight: .bold)
        label.textColor = .mainColor
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return label
    }()

    private lazy var sourceLabel: Label = {
        let label = Label()
        label.font = .ddp_small()
        label.textColor = .secondaryLabel
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return label
    }()

    private lazy var commentTextLabel: Label = {
        let label = Label()
        label.font = .ddp_normal()
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()

    private lazy var timeLabel: Label = {
        let label = Label()
        label.font = .ddp_small()
        label.textColor = .secondaryLabel
        return label
    }()

    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    func update(comment: BangumiComment) {
        if !comment.imageUrl.isEmpty {
            avatarImageView.kf.setImage(with: URL(string: comment.imageUrl), placeholder: UIImage.placeholder)
        } else {
            avatarImageView.image = UIImage.placeholder
        }

        userNameLabel.text = comment.userName
        commentTextLabel.text = comment.text

        if comment.rating > 0 {
            ratingLabel.text = "⭐ \(comment.rating)"
            ratingLabel.isHidden = false
        } else {
            ratingLabel.isHidden = true
        }

        if !comment.source.isEmpty {
            sourceLabel.text = comment.source
            sourceLabel.isHidden = false
        } else {
            sourceLabel.isHidden = true
        }

        if let updatedTime = comment.updatedTime {
            timeLabel.text = dateFormatter.string(from: updatedTime)
        } else {
            timeLabel.text = nil
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        let topStack = UIStackView(arrangedSubviews: [avatarImageView, userNameLabel, ratingLabel, sourceLabel])
        topStack.axis = .horizontal
        topStack.spacing = 12
        topStack.alignment = .center

        contentView.addSubview(topStack)
        contentView.addSubview(commentTextLabel)
        contentView.addSubview(timeLabel)

        avatarImageView.snp.makeConstraints { make in
            make.size.equalTo(avatarSize)
        }

        topStack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.equalToSuperview().offset(60)
            make.trailing.equalToSuperview().offset(-60)
        }

        commentTextLabel.snp.makeConstraints { make in
            make.top.equalTo(topStack.snp.bottom).offset(12)
            make.leading.equalToSuperview().offset(60)
            make.trailing.equalToSuperview().offset(-60)
        }

        timeLabel.snp.makeConstraints { make in
            make.top.equalTo(commentTextLabel.snp.bottom).offset(8)
            make.leading.equalToSuperview().offset(60)
            make.trailing.equalToSuperview().offset(-60)
            make.bottom.equalToSuperview().offset(-16)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
