//
//  BangumiCommentTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/7/8.
//

import UIKit
import Kingfisher

class BangumiCommentTableViewCell: TableViewCell {

    private let avatarSize = CGSize(width: 24, height: 24)

    private lazy var avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = avatarSize.width / 2
        return iv
    }()

    private lazy var userNameLabel: Label = {
        let label = Label()
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    private lazy var ratingLabel: Label = {
        let label = Label()
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return label
    }()

    private lazy var sourceLabel: Label = {
        let label = Label()
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return label
    }()

    private lazy var commentTextLabel: Label = {
        let label = Label()
        label.numberOfLines = 0
        return label
    }()

    private lazy var timeLabel: Label = {
        let label = Label()
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
        topStack.spacing = 8
        topStack.alignment = .center

        contentView.addSubview(topStack)
        contentView.addSubview(commentTextLabel)
        contentView.addSubview(timeLabel)

        avatarImageView.snp.makeConstraints { make in
            make.size.equalTo(avatarSize)
        }

        topStack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.leading.equalToSuperview().offset(15)
            make.trailing.equalToSuperview().offset(-15)
        }

        commentTextLabel.snp.makeConstraints { make in
            make.top.equalTo(topStack.snp.bottom).offset(8)
            make.leading.equalToSuperview().offset(15)
            make.trailing.equalToSuperview().offset(-15)
        }

        timeLabel.snp.makeConstraints { make in
            make.top.equalTo(commentTextLabel.snp.bottom).offset(6)
            make.leading.equalToSuperview().offset(15)
            make.trailing.equalToSuperview().offset(-15)
            make.bottom.equalToSuperview().offset(-10)
        }

        userNameLabel.font = .ddp_normal
        ratingLabel.font = .ddp_small
        ratingLabel.textColor = .mainColor
        sourceLabel.font = .ddp_small
        sourceLabel.textColor = .subtitleTextColor
        commentTextLabel.font = .ddp_normal
        timeLabel.font = .ddp_small
        timeLabel.textColor = .subtitleTextColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
