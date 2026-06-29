//
//  SectionHeaderView.swift
//  AniXPlayer
//
//  tvOS 通用 Section Header — 自适应文字颜色，垂直居中
//

import UIKit
import SnapKit

class SectionHeaderView: UITableViewHeaderFooterView {

    var title: String? {
        didSet { titleLabel.text = title }
    }

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .ddp_normal(weight: .bold)
        label.textColor = .adaptiveText
        return label
    }()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
            make.centerY.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
