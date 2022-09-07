//
//  ProgressSlider.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/4/17.
//

import UIKit

private class TrackLayer: CALayer {
    weak var slider: ProgressSlider?

    override func draw(in ctx: CGContext) {
        guard let slider = slider else {
            return
        }

        let lowerValuePosition = CGFloat(slider.positionForValue(slider.value))

        // Fill the highlighted range
        ctx.setFillColor(slider.trackHighlightTintColor.cgColor)
        
        let rect = CGRect(x: lowerValuePosition, y: 0.0, width: bounds.width - lowerValuePosition, height: bounds.height)
        ctx.fill(rect)
        
        ctx.setFillColor(slider.trackBufferColor.cgColor)
        for info in slider.bufferInfos {
            let infoRect = CGRect(x: info.startPositin * bounds.width, y: 0, width: (info.endPositin - info.startPositin) * bounds.width, height: bounds.height)
            ctx.fill(infoRect)
        }
        
        // Clip
        let cornerRadius = bounds.height * slider.curvaceousness / 2.0
        let path = UIBezierPath(roundedRect: .init(x: 0, y: 0, width: lowerValuePosition, height: bounds.height), cornerRadius: cornerRadius)
        ctx.addPath(path.cgPath)

        // Fill the track
        ctx.setFillColor(slider.trackTintColor.cgColor)
        ctx.addPath(path.cgPath)
        ctx.fillPath()
        
    }
    
    override func action(forKey event: String) -> CAAction? {
        return nil
    }
}

private class ThumbLayer: CALayer {
    
    var highlighted: Bool = false {
        didSet {
            setNeedsDisplay()
        }
    }
    
    weak var slider: ProgressSlider?
    
    var strokeColor: UIColor = UIColor.gray {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var lineWidth: CGFloat = 0.5 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override func draw(in ctx: CGContext) {
        guard let slider = slider else {
            return
        }
        
        let thumbFrame = bounds.insetBy(dx: 2.0, dy: 2.0)
        let cornerRadius = thumbFrame.height * slider.curvaceousness / 2.0
        let thumbPath = UIBezierPath(roundedRect: thumbFrame, cornerRadius: cornerRadius)
        
        // Fill
        ctx.setFillColor(slider.thumbTintColor.cgColor)
        ctx.addPath(thumbPath.cgPath)
        ctx.fillPath()
        
        // Outline
        ctx.setStrokeColor(strokeColor.cgColor)
        ctx.setLineWidth(lineWidth)
        ctx.addPath(thumbPath.cgPath)
        ctx.strokePath()
        
        if highlighted {
            ctx.setFillColor(UIColor(white: 0.0, alpha: 0.1).cgColor)
            ctx.addPath(thumbPath.cgPath)
            ctx.fillPath()
        }
    }
    
    override func action(forKey event: String) -> CAAction? {
        return nil
    }
}

@IBDesignable
public class ProgressSlider: UIControl {
    @IBInspectable public var minimumValue: Double = 0.0 {
        willSet(newValue) {
            assert(newValue < maximumValue, "RangeSlider: minimumValue should be lower than maximumValue")
        }
        didSet {
            updateLayerFrames()
        }
    }
    
    @IBInspectable public var maximumValue: Double = 1.0 {
        willSet(newValue) {
            assert(newValue > minimumValue, "RangeSlider: maximumValue should be greater than minimumValue")
        }
        didSet {
            updateLayerFrames()
        }
    }
    
    @IBInspectable public var value: Double = 0 {
        didSet {
            updateLayerFrames()
        }
    }
    
    @IBInspectable public var trackTintColor: UIColor = UIColor(white: 0.9, alpha: 1.0) {
        didSet {
            trackLayer.setNeedsDisplay()
        }
    }
    
    @IBInspectable public var trackHighlightTintColor: UIColor = UIColor(red: 0.0, green: 0.45, blue: 0.94, alpha: 1.0) {
        didSet {
            trackLayer.setNeedsDisplay()
        }
    }
    
    @IBInspectable public var trackBufferColor: UIColor = .red {
        didSet {
            trackLayer.setNeedsDisplay()
        }
    }
    
    @IBInspectable public var thumbTintColor: UIColor = UIColor.white {
        didSet {
            thumbLayer.setNeedsDisplay()
        }
    }
    
    @IBInspectable public var thumbBorderColor: UIColor = UIColor.gray {
        didSet {
            thumbLayer.strokeColor = thumbBorderColor
        }
    }
    
    @IBInspectable public var thumbBorderWidth: CGFloat = 0.5 {
        didSet {
            thumbLayer.lineWidth = thumbBorderWidth
        }
    }
    
    @IBInspectable public var curvaceousness: CGFloat = 1.0 {
        didSet {
            if curvaceousness < 0.0 {
                curvaceousness = 0.0
            }
            
            if curvaceousness > 1.0 {
                curvaceousness = 1.0
            }
            
            trackLayer.setNeedsDisplay()
            thumbLayer.setNeedsDisplay()
        }
    }
    
    var thumbHitTestSlop = UIEdgeInsets.zero
    
    var bufferInfos = [MediaBufferInfo]() {
        didSet {
            trackLayer.setNeedsDisplay()
        }
    }
    
    fileprivate var previouslocation = CGPoint()
    
    fileprivate let trackLayer = TrackLayer()
    fileprivate let thumbLayer = ThumbLayer()
    
    fileprivate var thumbWidth: CGFloat {
        return min(CGFloat(bounds.height), 20)
    }
    
    override public var frame: CGRect {
        didSet {
            updateLayerFrames()
        }
    }
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        initializeLayers()
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        initializeLayers()
    }
    
    override public func layoutSublayers(of: CALayer) {
        super.layoutSublayers(of:layer)
        updateLayerFrames()
    }
    
    fileprivate func initializeLayers() {
        layer.backgroundColor = UIColor.clear.cgColor
        
        trackLayer.slider = self
        trackLayer.contentsScale = UIScreen.main.scale
        layer.addSublayer(trackLayer)
        
        thumbLayer.slider = self
        thumbLayer.contentsScale = UIScreen.main.scale
        layer.addSublayer(thumbLayer)
    }
    
    func updateLayerFrames() {
        
        let trackLayerHeight: CGFloat = 5
        trackLayer.frame = .init(x: 0, y: (bounds.height - trackLayerHeight) / 2, width: bounds.width, height: trackLayerHeight)
        trackLayer.setNeedsDisplay()
        
        let lowerThumbCenter = CGFloat(positionForValue(self.value))
        thumbLayer.frame = CGRect(x: lowerThumbCenter - thumbWidth/2.0, y: (bounds.height - thumbWidth) / 2, width: thumbWidth, height: thumbWidth)
        thumbLayer.setNeedsDisplay()
    }
    
    func positionForValue(_ value: Double) -> Double {
        return Double(bounds.width - thumbWidth) * (value - minimumValue) /
            (maximumValue - minimumValue) + Double(thumbWidth/2.0)
    }
    
    func boundValue(_ value: Double, toLowerValue lowerValue: Double, upperValue: Double) -> Double {
        return min(max(value, lowerValue), upperValue)
    }
    
    
    // MARK: - Touches
    
    override public func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        previouslocation = touch.location(in: self)
        
        let frame = thumbLayer.frame.inset(by: self.thumbHitTestSlop)
        
        // Hit test the thumb layers
        if frame.contains(previouslocation) {
            thumbLayer.highlighted = true
        }
        
        return thumbLayer.highlighted
    }
    
    override public func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let location = touch.location(in: self)
        
        // Determine by how much the user has dragged
        let deltaLocation = Double(location.x - previouslocation.x)
        let deltaValue = (maximumValue - minimumValue) * deltaLocation / Double(bounds.width)
        
        previouslocation = location
        
        // Update the values
        if thumbLayer.highlighted {
            self.value = boundValue(self.value + deltaValue, toLowerValue: minimumValue, upperValue: maximumValue)
        }
        
        sendActions(for: .valueChanged)
        
        return true
    }
    
    override public func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        thumbLayer.highlighted = false
    }
}
