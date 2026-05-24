//
//  SearchEpisodeCell.swift
//  AniXPlayer
//
//  tvOS 搜索结果分集 Cell
//

import UIKit
import SnapKit

class SearchEpisodeCell: TableViewCell {

    static let reuseIdentifier = "SearchEpisodeCell"

    private lazy var titleLabel: Label = {
        let label = Label()
        label.font = .ddp_small()
        label.textColor = .label
        label.numberOfLines = 0
        return label
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

        titleLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20))
        }
    }

    func configure(with item: MediaMatchItem) {
        titleLabel.text = item.title
    }
}