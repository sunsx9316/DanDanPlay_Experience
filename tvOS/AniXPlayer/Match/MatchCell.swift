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

    private lazy var animeTitleLabel: Label = {
        let label = Label()
        label.font = .systemFont(ofSize: 22, weight: .medium)
        label.textColor = .label
        return label
    }()

    private lazy var episodeTitleLabel: Label = {
        let label = Label()
        label.font = .systemFont(ofSize: 18)
        label.textColor = .secondaryLabel
        return label
    }()

    private lazy var typeLabel: Label = {
        let label = Label()
        label.font = .systemFont(ofSize: 15)
        label.textColor = .tertiaryLabel
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
            make.trailing.equalToSuperview().offset(-20)
            make.top.equalToSuperview().offset(20)
        }

        episodeTitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(animeTitleLabel)
            make.trailing.equalTo(animeTitleLabel)
            make.top.equalTo(animeTitleLabel.snp.bottom).offset(8)
        }

        typeLabel.snp.makeConstraints { make in
            make.leading.equalTo(animeTitleLabel)
            make.top.equalTo(episodeTitleLabel.snp.bottom).offset(8)
            make.bottom.equalToSuperview().offset(-20)
        }
    }

    func configure(with match: Match) {
        animeTitleLabel.text = match.animeTitle
        episodeTitleLabel.text = match.episodeTitle
        typeLabel.text = match.typeDescription
    }
}
