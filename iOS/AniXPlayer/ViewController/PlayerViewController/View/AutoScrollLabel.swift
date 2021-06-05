//
//  AutoScrollLabel.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/24.
//

import UIKit

/// 自动滚动的标签视图
class AutoScrollLabel: UIView {
    
    private class LabelModel {
        
        var attributedString: NSAttributedString?
        
        var frame = CGRect.zero
        
        init(attributedString: NSAttributedString?, frame: CGRect) {
            self.attributedString = attributedString
            self.frame = frame
        }
    }
    
    private lazy var displayLink: CADisplayLink = {
        let displayLink = CADisplayLink(target: self, selector: #selector(displayLinkStart(_:)))
        displayLink.isPaused = true
        displayLink.add(to: .current, forMode: .common)
        return displayLink
    }()
    
    private let scrollSpeed: CGFloat = 1
    
    private let padding: CGFloat = 50
    
    private var shouldScroll: Bool {
        
        guard let labelModel = self.labelModels?.first else { return false }
        
        if labelModel.frame.size.width > self.frame.size.width {
            return true
        }
        return false
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupInit()
    }
    
    var attributedString: NSAttributedString? {
        didSet {
            if let attributedString = self.attributedString {
                let rect = attributedString.boundingRect(with: .init(width: .max, height: .max), options: [], context: nil)
                let labelModel1 = LabelModel(attributedString: attributedString, frame: rect)
                
                var rect2 = rect
                rect2.origin.x = rect2.maxX + self.padding
                let labelModel2 = LabelModel(attributedString: attributedString, frame: rect2)
                self.labelModels = [labelModel1, labelModel2]
            } else {
                self.labelModels = nil
            }
        }
    }
    
    private var labelModels: [LabelModel]?
    
    deinit {
        self.displayLink.invalidate()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if self.shouldScroll {
            self.start()
        } else {
            self.paused()
        }
    }
    
    override func draw(_ rect: CGRect) {
        
        let ctx = UIGraphicsGetCurrentContext()
        ctx?.clear(rect)
        
        if let labelModels = self.labelModels {
            if self.shouldScroll {
                for labelModel in labelModels {
                    var frame = labelModel.frame
                    frame.origin.y = (self.frame.size.height - frame.size.height) / 2
                    labelModel.attributedString?.draw(at: frame.origin)
                }
            } else if let labelModel = labelModels.first {
                var frame = labelModel.frame
                frame.origin.y = (self.frame.size.height - frame.size.height) / 2
                labelModel.attributedString?.draw(at: .init(x: 0, y: frame.origin.y))
            }
        }
    }
    
    func start() {
        self.displayLink.isPaused = false
        self.setNeedsDisplay()
    }
    
    func paused() {
        self.displayLink.isPaused = true
    }
    
    @objc private func displayLinkStart(_ link: CADisplayLink) {
        self.updatePosition()
        self.setNeedsDisplay()
    }
    
    private func updatePosition() {
        if let labelModels = self.labelModels, labelModels.count > 1 {
            
            for (index, labelModel) in labelModels.enumerated() {
                labelModel.frame.origin.x -= scrollSpeed
                
                if labelModel.frame.maxX <= 0 {
                    if index == 0 {
                        labelModel.frame.origin.x = labelModels[1].frame.maxX + self.padding
                    } else if index == 1 {
                        labelModel.frame.origin.x = labelModels[0].frame.maxX + self.padding
                    }
                }
            }
        }
    }
    
    private func setupInit() {
        self.backgroundColor = .clear
    }
    
}
