//
//  Danmaku.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/8/24.
//

import Foundation
import DanmakuRender

/// 重复弹幕信息
class RepeatDanmakuInfo {
    
    weak var danmaku: DanmakuEntity?
    
    /// 重复次数
    var repeatCount = 0 {
        didSet {
            guard let danmaku = self.danmaku else { return }
            
            danmaku.newResizeCallBack = { [weak self] oldSize in
                guard let self = self else { return oldSize }
                
                let attStr = self.createRepeatStr(textColor: self.textColor, font: danmaku.font)
                let attStrSize = attStr.size()
                let newSize = CGSize(width: oldSize.width + attStrSize.width + 3, height: CGFloat.maximum(attStrSize.height, oldSize.height))
                return newSize
            }
            
            danmaku.isNeedsLayout = true
            danmaku.isNeedsRedraw = true
        }
    }
    
    private var textColor: ANXColor {
        return ANXColor.mainColor
    }
    
    init(danmaku: DanmakuEntity) {
        self.danmaku = danmaku
    }
    
    func draw(_ context: CGContext, size: CGSize, isCancelled: @escaping (() -> Bool)) {
        guard let danmaku = danmaku, self.repeatCount > 0 else { return }
        
        let attStr = self.createRepeatStr(textColor: self.textColor, font: danmaku.font)
        
        let textSize = attStr.size()
        
        if danmaku.effectStyle == .stroke {
            let startPoint = CGPoint(x: size.width - textSize.width - 2, y: (size.height - textSize.height) / 2)
            
            let strokeColor = danmaku.effectColor
            
            //绘制描边
            context.setLineWidth(3)
            context.setLineJoin(.round)
            context.setTextDrawingMode(.stroke)
            context.setStrokeColor(strokeColor.cgColor)
            
            let strokeAttStr = self.createRepeatStr(textColor: strokeColor, font: danmaku.font)
            strokeAttStr.draw(at: startPoint)
            
            //绘制文字
            context.setTextDrawingMode(.fill)
            attStr.draw(at: startPoint)
            
        } else {
            let startPoint = CGPoint(x: size.width - textSize.width - 1, y: (size.height - textSize.height) / 2)
            attStr.draw(at: startPoint)
        }
    }
    
    private func createRepeatStr(textColor: ANXColor?, font: ANXFont) -> NSAttributedString {
        guard let danmaku = self.danmaku else { return NSAttributedString(string: "") }
        
        let danmakuFontSize = danmaku.font.pointSize
        
        var attributes = danmaku.attributes
        attributes[.foregroundColor] = textColor
        attributes[.font] = font
        
        var xAttributes = attributes
        xAttributes[.font] = ANXFont.systemFont(ofSize: danmakuFontSize * 0.8)
        
        let attStr = NSMutableAttributedString(string: "x", attributes: xAttributes)
        attStr.append(.init(string: "\(self.repeatCount + 1)", attributes: attributes))
        
        return attStr
    }
    
}

protocol DanmakuInfoProtocol: AnyObject {
    
    /// 记录原始的出现时间
    var originAppearTime: TimeInterval? { set get }
    
    /// 弹幕重复信息
    var repeatDanmakuInfo: RepeatDanmakuInfo? { set get }
    
    /// 是否被过滤
    var isFilter: Bool { set get }
    
    var newResizeCallBack: ((CGSize) -> CGSize)? { set get }
    
    var changeFontCallBack: ((DRFont) -> Void)? { set get }

}

class _ScrollDanmaku: ScrollDanmaku, DanmakuInfoProtocol {
    
    var originAppearTime: TimeInterval?
    
    var repeatDanmakuInfo: RepeatDanmakuInfo?
    
    var isFilter: Bool = false
    
    var newResizeCallBack: ((CGSize) -> CGSize)?
    
    var changeFontCallBack: ((DRFont) -> Void)?
    
    override var font: DRFont {
        willSet {
            self.changeFontCallBack?(newValue)
        }
    }
    
    override func moveOutFromCanvas(_ context: DanmakuContext) {
        super.moveOutFromCanvas(context)
        self.repeatDanmakuInfo = nil
    }
    
    override func draw(_ context: CGContext, size: CGSize, isCancelled: @escaping (() -> Bool)) {
        super.draw(context, size: size, isCancelled: isCancelled)
        self.repeatDanmakuInfo?.draw(context, size: size, isCancelled: isCancelled)
    }
    
    override func newDanmakuSize(_ oldSize: CGSize) -> CGSize {
        var size = super.newDanmakuSize(oldSize)
        if let newSize = self.newResizeCallBack?(size) {
            size = newSize
        }
        return size
    }
}
 

class _FloatDanmaku: FloatDanmaku, DanmakuInfoProtocol {
    
    var originAppearTime: TimeInterval?
    
    var repeatDanmakuInfo: RepeatDanmakuInfo?
    
    var isFilter: Bool = false
    
    var newResizeCallBack: ((CGSize) -> CGSize)?
    
    var changeFontCallBack: ((DRFont) -> Void)?
    
    var willMoveOutCanvasCallBack: (() -> Void)?
    
    override var font: DRFont {
        willSet {
            self.changeFontCallBack?(newValue)
        }
    }
    
    override func moveOutFromCanvas(_ context: DanmakuContext) {
        super.moveOutFromCanvas(context)
        self.repeatDanmakuInfo = nil
    }
    
    override func draw(_ context: CGContext, size: CGSize, isCancelled: @escaping (() -> Bool)) {
        super.draw(context, size: size, isCancelled: isCancelled)
        self.repeatDanmakuInfo?.draw(context, size: size, isCancelled: isCancelled)
    }
    
    override func newDanmakuSize(_ oldSize: CGSize) -> CGSize {
        var size = super.newDanmakuSize(oldSize)
        if let newSize = self.newResizeCallBack?(size) {
            size = newSize
        }
        return size
    }
}
