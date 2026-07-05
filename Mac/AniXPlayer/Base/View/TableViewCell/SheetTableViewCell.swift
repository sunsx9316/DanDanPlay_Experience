//
//  SheetTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/15.
//

import Cocoa
import SnapKit

class SheetTableViewCell: NSView {

    lazy var titleLabel = Label()

    lazy var popUpButton = PopUpButton()

    var onClickButtonCallBack: ((Int) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(titleLabel)
        addSubview(popUpButton)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.top.equalToSuperview().offset(10)
            make.bottom.greaterThanOrEqualToSuperview().offset(-10)
        }
        popUpButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-10)
            make.centerY.equalTo(titleLabel)
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(10)
        }
        popUpButton.addTarget(self, action: #selector(onClickButton(_:)))
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func setItems(_ items: [String], selectedItem: String?) {
        popUpButton.removeAllItems()
        popUpButton.addItems(withTitles: items)
        if let selectedItem = selectedItem {
            popUpButton.selectItem(withTitle: selectedItem)
        }
    }

    @objc private func onClickButton(_ sender: NSPopUpButton) {
        onClickButtonCallBack?(sender.indexOfSelectedItem)
    }
}
