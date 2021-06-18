//
//  TextField.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/29.
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
    
    //MARK: Private
    private func setupInit() {
        self.font = .ddp_normal
        self.textColor = .textColor
    }

}
