//
//  EditableTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/14.
//

import UIKit
import SnapKit

class EditableTableViewCell: TableViewCell {

    lazy var titleLabel: Label = {
        let label = Label()
        label.numberOfLines = 0
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundView?.backgroundColor = .clear
        self.backgroundColor = .clear
        self.titleLabel.textColor = .textColor

        contentView.addSubview(titleLabel)

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(15)
            make.leading.equalToSuperview().offset(15)
            make.trailing.equalToSuperview().offset(-10)
            make.bottom.equalToSuperview().offset(-15)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.setupUI()
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)

        self.setupUI()
    }

    private func findReorderView() -> UIView? {
        var subviews = self.subviews
        var index = 0
        while index < subviews.count {
            let view = subviews[index]
            if view.className().contains("ReorderControl") {
                return view
            } else {
                subviews.append(contentsOf: view.subviews)
            }
            index += 1
        }

        return nil
    }

    private func setupUI() {
        if let reorderView = self.findReorderView() {
            for view in reorderView.subviews {
                if let imgView = view as? UIImageView {
                    imgView.image = UIImage(named: "Public/sort")?.byTintColor(.navItemColor)
                }
            }
        }
    }
}
