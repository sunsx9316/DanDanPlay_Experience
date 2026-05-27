//
//  SearchAnimeCell.swift
//  AniXPlayer
//
//  tvOS 搜索结果动漫 Cell (有分集的番剧)
//

import UIKit
import SnapKit

class SearchAnimeCell: TableViewCell {

    static let reuseIdentifier = "SearchAnimeCell"

    private lazy var typeLabel: Label = {
        let label = Label()
        label.backgroundColor = .mainColor
        label.textColor = .white
        label.font = .ddp_small()
        label.layer.cornerRadius = 3
        label.layer.masksToBounds = true
        label.textAlignment = .center
        return label
    }()

    private lazy var animeTitleLabel: Label = {
        let label = Label()
        label.font = .ddp_small(weight: .medium)
        label.textColor = .label
        return label
    }()

    private lazy var arrowImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "chevron.right"))
        iv.tintColor = .secondaryLabel
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

        contentView.addSubview(typeLabel)
        contentView.addSubview(animeTitleLabel)
        contentView.addSubview(arrowImageView)

        typeLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
        }

        animeTitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(typeLabel.snp.trailing).offset(10)
            make.top.equalToSuperview().offset(10)
            make.bottom.equalToSuperview().offset(-10)
            make.trailing.lessThanOrEqualTo(arrowImageView.snp.leading).offset(-10)
        }

        arrowImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
            make.width.equalTo(12)
            make.height.equalTo(20)
        }
    }

    func configure(with item: MediaMatchItem) {
        typeLabel.text = item.typeDesc
        animeTitleLabel.text = item.title
    }
}