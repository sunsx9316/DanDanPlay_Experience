//
//  Button.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/30.
//

import UIKit

class Button: UIButton {
    
    var contentSizeEdge = CGSize.zero
    
    // 自定义点击区域的边距
    var touchAreaEdgeInsets = UIEdgeInsets.zero
    
    override var intrinsicContentSize: CGSize {
        let intrinsicContentSize = super.intrinsicContentSize
        
        if contentSizeEdge == .zero {
            return intrinsicContentSize
        }
        
        return .init(width: intrinsicContentSize.width + contentSizeEdge.width, height: intrinsicContentSize.height + contentSizeEdge.height)
    }
    
    // 重写 point(inside:with:) 方法
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let bounds = self.bounds
        // 根据 touchAreaEdgeInsets 扩展点击区域
        let enlargedBounds = bounds.inset(by: touchAreaEdgeInsets)
        // 检查点击点是否在扩展区域内
        return enlargedBounds.contains(point)
    }

}
