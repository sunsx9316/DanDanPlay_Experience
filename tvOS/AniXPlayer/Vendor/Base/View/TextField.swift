//
//  TextField.swift
//  AniXPlayer
//
//  tvOS TextField 基类
//

import UIKit

class TextField: UITextField {

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setupInit()
    }

    private func setupInit() {
        self.font = .ddp_normal()
        self.textColor = .white
        self.backgroundColor = .adaptiveSecondaryBackground
    }
}
