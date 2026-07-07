//
//  ANXHUDBarProgressView.swift
//  AniXPlayer
//
//  水平进度条（iOS + tvOS），对应 MBBarProgressView
//

#if os(iOS) || os(tvOS)

import UIKit

class ANXHUDBarProgressView: UIView {

    var progress: Float = 0 {
        didSet { setNeedsDisplay() }
    }

    var lineColor: UIColor = .white {
        didSet { setNeedsDisplay() }
    }

    var progressRemainingColor: UIColor = .clear {
        didSet { setNeedsDisplay() }
    }

    var progressColor: UIColor = .white {
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
        return CGSize(width: 120, height: 20)
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        let lineHeight: CGFloat = 2
        let horizontalMargin: CGFloat = 6
        let progressRect = bounds.insetBy(dx: horizontalMargin, dy: (bounds.height - lineHeight) / 2)
        let progressWidth = progressRect.width * CGFloat(max(0, min(1, progress)))

        // Track background
        context.setFillColor(progressRemainingColor.cgColor)
        context.fill(progressRect)

        // Track border
        context.setStrokeColor(lineColor.cgColor)
        context.setLineWidth(1)
        context.stroke(progressRect)

        // Progress fill
        if progress > 0 {
            var filledRect = progressRect
            filledRect.size.width = progressWidth
            context.setFillColor(progressColor.cgColor)
            context.fill(filledRect)

            // Progress border
            context.setStrokeColor(lineColor.cgColor)
            context.setLineWidth(1)
            context.stroke(filledRect)
        }
    }
}

#endif
