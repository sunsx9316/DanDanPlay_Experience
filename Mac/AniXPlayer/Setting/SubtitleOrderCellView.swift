//
//  SubtitleOrderCellView.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/28.
//

import Cocoa
import SnapKit

class SubtitleOrderCellView: BaseView {

    lazy var label: Label = {
        let label = Label()
        label.font = .ddp_normal
        return label
    }()

    lazy var deleteButton: Button = {
        let button = Button.custom()
        button.title = "✕"
        button.font = .ddp_small
        button.contentTintColor = .subtitleTextColor
        return button
    }()

    var onClickDeleteCallBack: ((SubtitleOrderCellView) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(label)
        addSubview(deleteButton)

        label.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.centerY.equalToSuperview()
            make.top.equalToSuperview().offset(4)
            make.bottom.equalToSuperview().offset(-4)
        }

        deleteButton.snp.makeConstraints { make in
            make.leading.equalTo(label.snp.trailing).offset(8)
            make.trailing.equalToSuperview().offset(-10)
            make.centerY.equalToSuperview()
        }

        deleteButton.addTarget(self, action: #selector(onClickDelete(_:)))
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    @objc private func onClickDelete(_ sender: NSButton) {
        onClickDeleteCallBack?(self)
    }
}
