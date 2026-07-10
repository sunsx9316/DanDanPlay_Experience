//
//  TitleMoreTableViewCell.swift
//  AniXPlayer
//
//  tvOS TitleMoreTableViewCell 基类
//

import UIKit
import SnapKit

class TitleMoreTableViewCell: TableViewCell {


    lazy var label: UILabel = {
        let label = Label()
        label.textColor = .adaptiveText
        label.font = .ddp_normal()
        return label
    }()

    private lazy var arrowImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(named: "Public/right_arrow")?.byTintColor(.secondaryLabel)
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        accessoryType = .none
        contentView.addSubview(label)
        contentView.addSubview(arrowImageView)

        label.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
        }

        arrowImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(20)
            make.leading.greaterThanOrEqualTo(label.snp.trailing).offset(12)
        }
    }
}
