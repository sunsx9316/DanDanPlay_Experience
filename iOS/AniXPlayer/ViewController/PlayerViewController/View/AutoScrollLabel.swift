//
//  AutoScrollLabel.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/24.
//

import UIKit

class AutoScrollLabel: UIView {
    
    private class LabelModel {
        
        var attributedString: NSAttributedString?
        
        var origin = CGPoint.zero
        
        init(attributedString: NSAttributedString?, origin: CGPoint) {
            self.attributedString = attributedString
            self.origin = origin
        }
    }
    
    private lazy var displayLink: CADisplayLink = {
        let displayLink = CADisplayLink(target: self, selector: #selector(displayLinkStart(_:)))
        displayLink.isPaused = true
        return displayLink
    }()
    
    private let scrollSpeed: CGFloat = 0.01
    
    var attributedString: NSAttributedString? {
        didSet {
            if let attributedString = self.attributedString {
                let labelModel1 = LabelModel(attributedString: attributedString, origin: .zero)
                let rect = attributedString.boundingRect(with: .init(width: .max, height: .max), options: [], context: nil)
                let labelModel2 = LabelModel(attributedString: attributedString, origin: .init(x: rect.maxX + 10, y: 0))
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
        if let labelModels = self.labelModels {
            
            let rect = self.attributedString?.boundingRect(with: .init(width: .max, height: .max), options: [], context: nil) ?? .zero
            
            for labelModel in labelModels {
                labelModel.origin.x -= scrollSpeed
                
                if labelModel.origin.x + rect.size.width <= 0 {
                    labelModel.origin.x = self.bounds.size.width
                }
            }
        }
    }
    
    override func draw(_ rect: CGRect) {
        if let labelModels = self.labelModels {
            for labelModel in labelModels {
                labelModel.attributedString?.draw(at: labelModel.origin)
            }
        }
    }
    
}
