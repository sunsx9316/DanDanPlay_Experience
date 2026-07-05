//
//  EpisodeCellView.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/30.
//

import Cocoa
import SnapKit

class EpisodeCellView: NSTableCellView {

    private let titleField: Label = {
        let tf = Label(labelWithString: "")
        tf.font = .ddp_normal()
        tf.textColor = .textColor
        tf.lineBreakMode = .byTruncatingTail
        return tf
    }()

    private let detailField: Label = {
        let tf = Label(labelWithString: "")
        tf.font = .ddp_small()
        tf.textColor = .subtitleTextColor
        tf.lineBreakMode = .byTruncatingTail
        return tf
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        addSubview(titleField)
        addSubview(detailField)

        titleField.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalToSuperview().offset(8)
            make.trailing.equalToSuperview().offset(-20)
        }

        detailField.snp.makeConstraints { make in
            make.leading.equalTo(titleField)
            make.top.equalTo(titleField.snp.bottom).offset(2)
            make.trailing.equalTo(titleField)
        }
    }

    func configure(title: String, detail: String) {
        titleField.text = title
        detailField.text = detail
    }
}
