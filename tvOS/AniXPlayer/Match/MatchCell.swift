//
//  MatchCell.swift
//  AniXPlayer
//
//  tvOS 弹幕匹配结果 Cell
//

import UIKit
import SnapKit

class MatchCell: TableViewCell {

    static let reuseIdentifier = "MatchCell"

    private let animeTitleLabel: Label = {
        let label = Label()
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textColor = .lightGray
        return label
    }()

    private let episodeTitleLabel: Label = {
        let label = Label()
        label.font = .systemFont(ofSize: 15)
        label.textColor = .lightGray
        return label
    }()

    private let typeLabel: Label = {
        let label = Label()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .lightGray
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
        contentView.addSubview(animeTitleLabel)
        contentView.addSubview(episodeTitleLabel)
        contentView.addSubview(typeLabel)

        animeTitleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalToSuperview().offset(14)
            make.trailing.equalToSuperview().offset(-20)
        }

        episodeTitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(animeTitleLabel)
            make.top.equalTo(animeTitleLabel.snp.bottom).offset(4)
        }

        typeLabel.snp.makeConstraints { make in
            make.leading.equalTo(animeTitleLabel)
            make.top.equalTo(episodeTitleLabel.snp.bottom).offset(2)
        }
    }

    func configure(with match: Match) {
        animeTitleLabel.text = match.animeTitle
        episodeTitleLabel.text = match.episodeTitle
        typeLabel.text = match.typeDescription
    }
}
