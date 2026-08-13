//
//  DetailEpisodeRowCollectionViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/29.
//

import Cocoa
import SnapKit

class DetailEpisodeRowCollectionViewCell: CollectionViewItem {

    var onTap: (() -> Void)?

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.backgroundColor.cgColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let titleLabel = Label(labelWithString: NSLocalizedString("分集详情", comment: ""))
        titleLabel.font = .ddp_normal()
        titleLabel.textColor = .textColor

        let subtitleLabel = Label(labelWithString: NSLocalizedString("分集信息、观看信息等", comment: ""))
        subtitleLabel.font = .ddp_small()
        subtitleLabel.textColor = .subtitleTextColor

        let arrowImageView = ImageView()
        arrowImageView.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)
        arrowImageView.contentTintColor = .subtitleTextColor

        let separator = NSView()
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.separatorColor.cgColor

        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(arrowImageView)
        view.addSubview(separator)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalToSuperview().offset(12)
            make.trailing.equalTo(arrowImageView.snp.leading).offset(-8)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
        }

        arrowImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-15)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }

        separator.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
            make.height.equalTo(1)
        }

        let clickRecognizer = NSClickGestureRecognizer(target: self, action: #selector(itemClicked))
        view.addGestureRecognizer(clickRecognizer)
    }

    @objc private func itemClicked() {
        onTap?()
    }
}
