//
//  BangumiCommentTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/7/10.
//

import Cocoa
import SnapKit
import Kingfisher

class BangumiCommentTableViewCell: NSTableCellView {

    private let avatarSize = NSSize(width: 24, height: 24)

    private lazy var avatarImageView: ImageView = {
        let iv = ImageView()
        iv.setScaling(.aspectFill)
        iv.wantsLayer = true
        iv.layer?.cornerRadius = avatarSize.width / 2
        iv.layer?.masksToBounds = true
        return iv
    }()

    private lazy var userNameLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .ddp_normal()
        label.textColor = .textColor
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    private lazy var ratingLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .ddp_small()
        label.textColor = .mainColor
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return label
    }()

    private lazy var sourceLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .ddp_small()
        label.textColor = .subtitleTextColor
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return label
    }()

    private lazy var commentTextLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .ddp_normal()
        label.textColor = .textColor
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    private lazy var timeLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .ddp_small()
        label.textColor = .subtitleTextColor
        return label
    }()

    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    private lazy var topStack: NSStackView = {
        let stack = NSStackView(views: [avatarImageView, userNameLabel, ratingLabel, sourceLabel])
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        return stack
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        addSubview(topStack)
        addSubview(commentTextLabel)
        addSubview(timeLabel)

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
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(comment: BangumiComment) {
        if !comment.imageUrl.isEmpty {
            avatarImageView.kf.setImage(with: URL(string: comment.imageUrl))
        }

        userNameLabel.text = comment.userName
        commentTextLabel.text = comment.text

        if comment.rating > 0 {
            ratingLabel.text = String(format: NSLocalizedString("⭐ %.1f", comment: ""), Double(comment.rating))
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
}
