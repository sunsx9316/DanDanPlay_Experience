//
//  ANXHUDRoundProgressView.swift
//  AniXPlayer
//
//  圆形/环形进度视图（iOS + tvOS），对应 MBRoundProgressView
//

#if os(iOS) || os(tvOS)

import UIKit

class ANXHUDRoundProgressView: UIView {

    var progress: Float = 0 {
        didSet { setNeedsDisplay() }
    }

    var progressTintColor: UIColor = .white {
        didSet { setNeedsDisplay() }
    }

    var backgroundTintColor: UIColor = UIColor.white.withAlphaComponent(0.1) {
        didSet { setNeedsDisplay() }
    }

    var isAnnular: Bool = false {
        didSet { setNeedsDisplay() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isOpaque = false
    }

    override var intrinsicContentSize: CGSize {
        return CGSize(width: 37, height: 37)
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        let lineWidth: CGFloat = 2
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - lineWidth
        let startAngle: CGFloat = -.pi / 2
        let endAngle = startAngle + .pi * 2 * CGFloat(progress)

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
            context.setLineCap(.round)
            context.beginPath()
            context.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
            context.strokePath()
        } else {
            // Pie slice
            if progress > 0 {
                context.setFillColor(progressTintColor.cgColor)
                context.beginPath()
                context.move(to: center)
                context.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
                context.closePath()
                context.fillPath()
            }

            if progress < 1 {
                // Remaining background
                context.setStrokeColor(backgroundTintColor.cgColor)
                context.setLineWidth(lineWidth)
                context.beginPath()
                context.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: startAngle + .pi * 2, clockwise: false)
                context.strokePath()
            }
        }
    }
}

#endif
