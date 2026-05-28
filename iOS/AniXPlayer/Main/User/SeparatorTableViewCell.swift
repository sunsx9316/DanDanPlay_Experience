//
//  SeparatorTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/5/29.
//

import UIKit
import SnapKit

class SeparatorTableViewCell: TableViewCell {

    private lazy var separatorLine: UIView = {
        let view = UIView()
        view.backgroundColor = .separator
        return view
    }()

    var separatorInsetLeft: CGFloat = 20 {
        didSet {
            updateSeparatorConstraints()
        }
    }

    var showSeparator: Bool = true {
        didSet {
            separatorLine.isHidden = !showSeparator
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(separatorLine)
        updateSeparatorConstraints()
    }

    private func updateSeparatorConstraints() {
        separatorLine.snp.remakeConstraints { make in
            make.leading.equalToSuperview().offset(separatorInsetLeft)
            make.trailing.bottom.equalToSuperview()
            make.height.equalTo(1.0)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
