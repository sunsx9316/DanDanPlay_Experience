//
//  TitleDetailTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/27.
//

import Cocoa
import SnapKit

class TitleDetailTableViewCell: NSView {

    private enum Layout {
        static let horizontalInset: CGFloat = 10
        static let topInset: CGFloat = 10
        static let bottomInset: CGFloat = 10
        static let titleSpacing: CGFloat = 6
    }

    lazy var titleLabel: Label = {
        let label = Label()
        label.font = .ddp_large
        label.lineBreakMode = .byTruncatingTail
        label.usesSingleLineMode = true
        label.maximumNumberOfLines = 1
        label.cell?.truncatesLastVisibleLine = true
        /// 标题可以截断，优先保证副标题（字体名等）完整。
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }()

    lazy var subtitleLabel: Label = {
        let label = Label()
        label.font = .ddp_normal
        label.textColor = .subtitleTextColor
        label.lineBreakMode = .byTruncatingTail
        label.usesSingleLineMode = true
        label.maximumNumberOfLines = 1
        label.cell?.truncatesLastVisibleLine = true
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Layout.horizontalInset)
            make.top.equalToSuperview().offset(Layout.topInset)
            make.trailing.lessThanOrEqualToSuperview().offset(-Layout.horizontalInset)
        }
        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(Layout.titleSpacing)
            make.bottom.lessThanOrEqualToSuperview().offset(-Layout.bottomInset)
            make.trailing.lessThanOrEqualToSuperview().offset(-Layout.horizontalInset)
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func configure(title: String, subtitle: String?) {
        titleLabel.text = title
        titleLabel.toolTip = title

        let subtitle = subtitle ?? ""
        subtitleLabel.text = subtitle
        subtitleLabel.toolTip = subtitle.isEmpty ? nil : subtitle
    }
}
