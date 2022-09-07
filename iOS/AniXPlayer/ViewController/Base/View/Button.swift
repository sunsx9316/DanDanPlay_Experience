//
//  Button.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/30.
//

import UIKit

class Button: UIButton {
    
    var contentSizeEdge = CGSize.zero
    
    override var intrinsicContentSize: CGSize {
        let intrinsicContentSize = super.intrinsicContentSize
        
        if contentSizeEdge == .zero {
            return intrinsicContentSize
        }
        
        return .init(width: intrinsicContentSize.width + contentSizeEdge.width, height: intrinsicContentSize.height + contentSizeEdge.height)
    }

}
