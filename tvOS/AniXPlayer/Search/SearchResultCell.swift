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
        label.font = .systemFont(ofSize: 20, weight: .medium)
        label.textColor = .label
        return label
    }()

    private lazy var episodeIdLabel: Label = {
        let label = Label()
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
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
        contentView.addSubview(episodeTitleLabel)
        contentView.addSubview(episodeIdLabel)

        episodeTitleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.top.equalToSuperview().offset(20)
        }

        episodeIdLabel.snp.makeConstraints { make in
            make.leading.equalTo(episodeTitleLabel)
            make.top.equalTo(episodeTitleLabel.snp.bottom).offset(8)
            make.bottom.equalToSuperview().offset(-20)
        }
    }

    func configure(with search: Search) {
        episodeTitleLabel.text = search.episodeTitle.isEmpty ? search.animeTitle : search.episodeTitle
        episodeIdLabel.text = "ID: \(search.id)"
    }
}
