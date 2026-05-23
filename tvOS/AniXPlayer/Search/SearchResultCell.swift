//
//  SearchResultCell.swift
//  AniXPlayer
//
//  tvOS 搜索结果 Cell
//

import UIKit
import SnapKit

class SearchResultCell: TableViewCell {

    static let reuseIdentifier = "SearchResultCell"

    private lazy var episodeTitleLabel: Label = {
        let label = Label()
        label.font = .ddp_small(weight: .medium)
        label.textColor = .label
        return label
    }()

    private lazy var episodeIdLabel: Label = {
        let label = Label()
        label.font = .ddp_small()
        label.textColor = .secondaryLabel
        return label
    }()

    private lazy var textStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [episodeTitleLabel, episodeIdLabel])
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        return stack
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
        contentView.addSubview(textStack)

        textStack.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(60)
            make.trailing.equalToSuperview().offset(-60)
            make.top.equalToSuperview().offset(24)
            make.bottom.equalToSuperview().offset(-24)
        }
    }

    func configure(with search: Search) {
        episodeTitleLabel.text = search.episodeTitle.isEmpty ? search.animeTitle : search.episodeTitle
        episodeIdLabel.text = "ID: \(search.id)"
    }
}
