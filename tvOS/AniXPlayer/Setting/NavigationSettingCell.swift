//
//  NavigationSettingCell.swift
//  AniXPlayer
//
//  tvOS 导航设置 Cell — 点击跳转子页面
//

import UIKit
import SnapKit

class NavigationSettingCell: TableViewCell {

    static let reuseIdentifier = "NavigationSettingCell"

    var colorIndicatorColor: UIColor? {
        didSet {
            colorIndicator.backgroundColor = colorIndicatorColor
        }
    }

    private let titleLabel: Label = {
        let label = Label()
        label.font = .systemFont(ofSize: 18)
        label.textColor = .lightGray
        return label
    }()

    private let detailLabel: Label = {
        let label = Label()
        label.font = .systemFont(ofSize: 17)
        label.textColor = .lightGray
        return label
    }()

    private let colorIndicator: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 6
        view.isHidden = true
        return view
    }()

    private let disclosureImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "chevron.right"))
        iv.tintColor = .lightGray
        return iv
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        selectionStyle = .none
        accessoryType = .none

        contentView.addSubview(titleLabel)
        contentView.addSubview(colorIndicator)
        contentView.addSubview(detailLabel)
        contentView.addSubview(disclosureImageView)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
        }

        disclosureImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
            make.size.equalTo(CGSize(width: 12, height: 20))
        }

        detailLabel.snp.makeConstraints { make in
            make.trailing.equalTo(disclosureImageView.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
        }

        colorIndicator.snp.makeConstraints { make in
            make.trailing.equalTo(detailLabel.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
            make.size.equalTo(CGSize(width: 20, height: 20))
        }
    }

    func configure(title: String, detail: String) {
        titleLabel.text = title
        detailLabel.text = detail
        colorIndicator.isHidden = (colorIndicatorColor == nil)
    }
}
