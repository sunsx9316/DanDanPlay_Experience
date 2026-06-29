//
//  RoundProgressView.swift
//  ProgressHUD
//
//  圆形/环形进度视图，对齐 MBRoundProgressView
//

import AppKit

class RoundProgressView: NSView {

    var progress: Float = 0 {
        didSet { needsDisplay = true }
    }

    var progressTintColor: NSColor = .white {
        didSet { needsDisplay = true }
    }

    var backgroundTintColor: NSColor = NSColor.white.withAlphaComponent(0.1) {
        didSet { needsDisplay = true }
    }

    var isAnnular: Bool = false {
        didSet { needsDisplay = true }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        return NSSize(width: 37, height: 37)
    }

    override func draw(_ rect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let lineWidth: CGFloat = 2
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - lineWidth
        let startAngle: CGFloat = -.pi / 2
        let endAngle = startAngle + (.pi * 2 * CGFloat(progress))

        if isAnnular {
            // Background ring
            context.setStrokeColor(backgroundTintColor.cgColor)
            context.setLineWidth(lineWidth)
            context.beginPath()
            context.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            context.strokePath()

            // Progress ring
            context.setStrokeColor(progressTintColor.cgColor)
            context.setLineWidth(lineWidth)
            context.beginPath()
            context.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
            context.strokePath()
        } else {
            // Round (pie chart) style
            if progress > 0 {
                // Progress slice
                context.setFillColor(progressTintColor.cgColor)
                context.beginPath()
                context.move(to: center)
                context.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
                context.closePath()
                context.fillPath()
            }

            // Background circle
            context.setStrokeColor(backgroundTintColor.cgColor)
            context.setLineWidth(lineWidth)
            context.beginPath()
            context.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            context.strokePath()
        }
    }
}
