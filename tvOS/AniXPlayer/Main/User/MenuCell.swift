//
//  MenuCell.swift
//  AniXPlayer
//
//  tvOS 菜单 Cell — 图标 + 标题，水平 stackView 布局，无图标时自动隐藏
//

import UIKit
import SnapKit

class MenuCell: TableViewCell {

    static let reuseIdentifier = "MenuCell"

    private lazy var iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .label
        iv.isHidden = true
        return iv
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .ddp_normal()
        label.textColor = .label
        return label
    }()

    private lazy var stackView: UIStackView = {
        let sv = UIStackView(arrangedSubviews: [iconImageView, titleLabel])
        sv.axis = .horizontal
        sv.alignment = .center
        sv.spacing = 20
        return sv
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(stackView)
        iconImageView.snp.makeConstraints { make in
            make.width.height.equalTo(28)
        }
        stackView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(40)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview().offset(-40)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(icon: UIImage?, title: String) {
        titleLabel.text = title
        if let icon = icon {
            iconImageView.image = icon
            iconImageView.isHidden = false
        } else {
            iconImageView.image = nil
            iconImageView.isHidden = true
        }
    }
}
