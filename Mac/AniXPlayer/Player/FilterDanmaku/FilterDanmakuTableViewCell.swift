//
//  FilterDanmakuTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/27.
//

import Cocoa
import SnapKit

class FilterDanmakuTableViewCell: BaseView {

    lazy var enableCheckBox: CheckBox = {
        let button = CheckBox()
        return button
    }()

    lazy var textField: TextField = {
        let field = TextField()
        field.font = .ddp_small
        field.placeholderString = NSLocalizedString("屏蔽词", comment: "")
        return field
    }()

    lazy var deleteButton: Button = {
        let button = Button.custom()
        button.title = "✕"
        button.font = .ddp_small
        button.contentTintColor = .subtitleTextColor
        return button
    }()

    lazy var regexCheckBox: CheckBox = {
        let button = CheckBox()
        button.title = NSLocalizedString("正则表达式", comment: "")
        return button
    }()

    var onClickEnableCallBack: ((FilterDanmakuTableViewCell) -> Void)?
    var onClickRegexCallBack: ((FilterDanmakuTableViewCell) -> Void)?
    var onEndEditingCallBack: ((FilterDanmakuTableViewCell) -> Void)?
    var onClickDeleteCallBack: ((FilterDanmakuTableViewCell) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(enableCheckBox)
        addSubview(textField)
        addSubview(deleteButton)
        addSubview(regexCheckBox)

        enableCheckBox.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.centerY.equalToSuperview()
        }
        textField.snp.makeConstraints { make in
            make.leading.equalTo(enableCheckBox.snp.trailing).offset(10)
            make.centerY.equalToSuperview()
            make.top.equalToSuperview().offset(4)
            make.bottom.equalToSuperview().offset(-4)
        }
        deleteButton.snp.makeConstraints { make in
            make.leading.equalTo(textField.snp.trailing).offset(8)
            make.centerY.equalToSuperview()
        }
        regexCheckBox.snp.makeConstraints { make in
            make.leading.equalTo(deleteButton.snp.trailing).offset(8)
            make.trailing.equalToSuperview().offset(-10)
            make.centerY.equalToSuperview()
        }

        enableCheckBox.addTarget(self, action: #selector(onClickEnable(_:)))
        regexCheckBox.addTarget(self, action: #selector(onClickRegex(_:)))
        deleteButton.addTarget(self, action: #selector(onClickDelete(_:)))
        textField.delegate = self
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    @objc private func onClickEnable(_ sender: NSButton) {
        onClickEnableCallBack?(self)
    }

    @objc private func onClickRegex(_ sender: NSButton) {
        onClickRegexCallBack?(self)
    }

    @objc private func onClickDelete(_ sender: NSButton) {
        onClickDeleteCallBack?(self)
    }
}

extension FilterDanmakuTableViewCell: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        onEndEditingCallBack?(self)
    }
}
