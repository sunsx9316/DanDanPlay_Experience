//
//  BangumiDetailCommentPreviewView.swift
//  AniXPlayer
//
//  macOS：详情页社区卡片中的短评摘要。
//

import Cocoa
import SnapKit
import Kingfisher

final class BangumiDetailCommentPreviewView: NSView {

    private let avatarImageView = ImageView()
    private let nameLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .labelColor
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()
    private let ratingLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .mainColor
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()
    private let sourceLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .systemFont(ofSize: 10.5)
        label.textColor = .tertiaryLabelColor
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()
    private let timeLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .systemFont(ofSize: 10.5)
        label.textColor = .tertiaryLabelColor
        label.alignment = .right
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()
    private let textLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .systemFont(ofSize: 12.5)
        label.textColor = .labelColor
        label.maximumNumberOfLines = 3
        label.lineBreakMode = .byTruncatingTail
        label.cell?.wraps = true
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        effectiveAppearance.performAsCurrentDrawingAppearance { [weak self] in
            self?.avatarImageView.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        }
    }

    func update(comment: BangumiComment) {
        avatarImageView.kf.cancelDownloadTask()
        avatarImageView.image = NSImage.safeSystemSymbol("person.crop.circle.fill")
        avatarImageView.contentTintColor = .tertiaryLabelColor
        if let url = URL(string: comment.imageUrl), !comment.imageUrl.isEmpty {
            avatarImageView.kf.setImage(with: url)
        }

        nameLabel.text = comment.userName
        textLabel.text = comment.text

        if comment.rating > 0 {
            ratingLabel.text = String(format: "★ %d", comment.rating)
            ratingLabel.isHidden = false
        } else {
            ratingLabel.isHidden = true
        }

        sourceLabel.text = comment.source
        sourceLabel.isHidden = comment.source.isEmpty

        if let updatedTime = comment.updatedTime {
            timeLabel.text = BangumiDetailDateFormatter.minute.string(from: updatedTime)
            timeLabel.isHidden = false
        } else {
            timeLabel.text = ""
            timeLabel.isHidden = true
        }

        setAccessibilityLabel([
            comment.userName,
            comment.rating > 0 ? String(format: NSLocalizedString("评分 %d", comment: ""), comment.rating) : "",
            comment.source,
            comment.text
        ].filter { !$0.isEmpty }.joined(separator: "，"))
    }

    private func setup() {
        avatarImageView.setScaling(.aspectFill)
        avatarImageView.wantsLayer = true
        avatarImageView.layer?.cornerRadius = 14
        avatarImageView.layer?.cornerCurve = .continuous
        avatarImageView.layer?.masksToBounds = true
        avatarImageView.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let topRow = NSStackView(views: [nameLabel, ratingLabel, sourceLabel, spacer, timeLabel])
        topRow.orientation = .horizontal
        topRow.alignment = .centerY
        topRow.spacing = 7

        addSubview(avatarImageView)
        addSubview(topRow)
        addSubview(textLabel)

        avatarImageView.snp.makeConstraints { make in
            make.leading.top.equalToSuperview()
            make.width.height.equalTo(28)
        }
        topRow.snp.makeConstraints { make in
            make.leading.equalTo(avatarImageView.snp.trailing).offset(10)
            make.top.equalToSuperview().offset(1)
            make.trailing.equalToSuperview()
        }
        textLabel.snp.makeConstraints { make in
            make.leading.equalTo(topRow)
            make.top.equalTo(topRow.snp.bottom).offset(4)
            make.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }
}
