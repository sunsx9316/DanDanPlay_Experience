//
//  HomePageSectionHeaderView.swift
//  AniXPlayer
//
//  tvOS 首页 Section Header
//

import UIKit
import SnapKit

class HomePageSectionHeaderView: UICollectionReusableView {

    static let reuseIdentifier = "HomePageSectionHeaderView"

    var title: String? {
        didSet {
            titleLabel.text = title
        }
    }

    private let titleLabel: Label = {
        let label = Label()
        label.font = .ddp_large(weight: .bold)
        label.textColor = .white
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
