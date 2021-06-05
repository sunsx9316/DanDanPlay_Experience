//
//  Label.swift
//  Runner
//
//  Created by jimhuang on 2021/3/7.
//

import UIKit

class Label: UILabel {
    
    var padding: CGSize = .zero

    
    override var intrinsicContentSize: CGSize {
        var size = super.intrinsicContentSize
        if padding != .zero {
            size.width += padding.width
            size.height += padding.height
        }
        return size
    }
    
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
