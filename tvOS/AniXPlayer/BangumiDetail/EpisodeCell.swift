//
//  EpisodeCell.swift
//  AniXPlayer
//
//  tvOS 剧集列表 Cell
//

import UIKit
import SnapKit

class EpisodeCell: TableViewCell {

    static let reuseIdentifier = "EpisodeCell"

    private lazy var episodeNumberLabel: Label = {
        let label = Label()
        label.font = .ddp_small(weight: .semibold)
        label.textColor = .secondaryLabel
        return label
    }()

    private lazy var episodeTitleLabel: Label = {
        let label = Label()
        label.font = .ddp_small()
        label.textColor = .label
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
        contentView.addSubview(episodeNumberLabel)
        contentView.addSubview(episodeTitleLabel)

        episodeNumberLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
            make.width.equalTo(100)
        }

        episodeTitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(episodeNumberLabel.snp.trailing).offset(12)
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
        }
    }

    func configure(with episode: BangumiEpisode) {
        episodeNumberLabel.text = episode.episodeNumber
        episodeTitleLabel.text = episode.episodeTitle
    }
}
