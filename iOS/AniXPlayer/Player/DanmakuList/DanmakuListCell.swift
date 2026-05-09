//
//  DanmakuListCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/4/28.
//

import UIKit
import DanmakuRender

class DanmakuListCell: TableViewCell {

    private lazy var timeLabel: UILabel = {
        let label = UILabel()
        label.font = .ddp_small
        label.textColor = .subtitleTextColor
        return label
    }()

    private lazy var modeLabel: UILabel = {
        let label = UILabel()
        label.font = .ddp_small
        label.textColor = .subtitleTextColor
        return label
    }()

    private lazy var contentLabel: UILabel = {
        let label = UILabel()
        label.font = .ddp_large
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

    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }

    func configure(danmaku: DanmakuEntity) {
        let minutes = Int(danmaku.appearTime) / 60
        let seconds = Int(danmaku.appearTime) % 60
        timeLabel.text = String(format: "%02d:%02d", minutes, seconds)
        modeLabel.text = danmaku.rawComment?.mode.name

        contentLabel.text = danmaku.text
        contentLabel.textColor = danmaku.textColor
    }

    // MARK: - Private

    private func setupUI() {
        backgroundColor = .clear
        backgroundView?.backgroundColor = .clear

        contentView.addSubview(timeLabel)
        contentView.addSubview(modeLabel)
        contentView.addSubview(contentLabel)

        timeLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalToSuperview().offset(8)
        }

        modeLabel.snp.makeConstraints { make in
            make.leading.equalTo(timeLabel.snp.trailing).offset(8)
            make.top.equalTo(timeLabel)
        }

        contentLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.top.equalTo(timeLabel.snp.bottom).offset(4)
            make.bottom.equalToSuperview().offset(-8)
        }
    }
}
