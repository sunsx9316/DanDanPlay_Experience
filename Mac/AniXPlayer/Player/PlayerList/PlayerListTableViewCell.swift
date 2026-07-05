//
//  PlayerListTableViewCell.swift
//  Runner
//
//  Created by JimHuang on 2020/3/8.
//  Copyright © 2020 The Flutter Authors. All rights reserved.
//

import Cocoa
import SnapKit

class PlayerListTableViewCell: BaseView {

    private lazy var pointView: BaseView = {
        let view = BaseView()
        view.wantsLayer = true
        view.layer?.cornerRadius = 3.5
        view.layer?.masksToBounds = true
        view.layer?.backgroundColor = NSColor.green.cgColor
        return view
    }()

    private lazy var label: Label = {
        let label = Label()
        label.font = .ddp_normal
        return label
    }()

    var showPoint: Bool = false {
        didSet {
            pointView.isHidden = !self.showPoint
            label.snp.updateConstraints { make in
                make.leading.equalToSuperview().offset(self.showPoint ? 21 : 7)
            }
        }
    }

    var string: String? {
        didSet {
            self.label.text = self.string ?? ""
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(pointView)
        addSubview(label)
        pointView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(7)
            make.width.height.equalTo(7)
        }
        label.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(7)
            make.trailing.equalToSuperview().offset(-7)
            make.centerY.equalToSuperview()
        }
        pointView.snp.makeConstraints { make in
            make.centerY.equalTo(label)
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
