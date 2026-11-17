//
//  SheetTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/15.
//

import Cocoa
import SnapKit

class SheetTableViewCell: NSView {

    private enum Layout {
        static let horizontalInset: CGFloat = 10
        static let titleSpacing: CGFloat = 10
        /// 弹出菜单最小宽度，避免被长标题挤到不可用。
        static let minimumPopUpWidth: CGFloat = 160
    }

    lazy var titleLabel: Label = {
        let label = Label()
        /// 标题过长时截断，但保留比 popup 更高的抗压缩优先级。
        label.lineBreakMode = .byTruncatingTail
        label.usesSingleLineMode = true
        label.maximumNumberOfLines = 1
        label.cell?.truncatesLastVisibleLine = true
        label.setContentCompressionResistancePriority(NSLayoutConstraint.Priority(rawValue: 751), for: .horizontal)
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return label
    }()

    lazy var popUpButton: PopUpButton = {
        let button = PopUpButton()
        /// 菜单内容过长时收缩自身，而不是把标题挤没。
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        button.cell?.lineBreakMode = .byTruncatingTail
        button.cell?.truncatesLastVisibleLine = true
        return button
    }()

    var onClickButtonCallBack: ((Int) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(titleLabel)
        addSubview(popUpButton)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Layout.horizontalInset)
            make.centerY.equalToSuperview()
            make.trailing.equalTo(popUpButton.snp.leading).offset(-Layout.titleSpacing)
        }
        popUpButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Layout.horizontalInset)
            make.centerY.equalTo(titleLabel)
            make.width.greaterThanOrEqualTo(Layout.minimumPopUpWidth)
        }
        popUpButton.addTarget(self, action: #selector(onClickButton(_:)))
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func setTitle(_ title: String) {
        titleLabel.text = title
        titleLabel.toolTip = title
    }

    func setItems(_ items: [String], selectedItem: String?) {
        popUpButton.removeAllItems()
        popUpButton.addItems(withTitles: items)
        if let selectedItem = selectedItem, popUpButton.item(withTitle: selectedItem) != nil {
            popUpButton.selectItem(withTitle: selectedItem)
        }
        updatePopUpToolTip()
    }

    @objc private func onClickButton(_ sender: NSPopUpButton) {
        updatePopUpToolTip()
        onClickButtonCallBack?(sender.indexOfSelectedItem)
    }

    private func updatePopUpToolTip() {
        let title = popUpButton.titleOfSelectedItem
        popUpButton.toolTip = title?.isEmpty == false ? title : nil
    }
}
