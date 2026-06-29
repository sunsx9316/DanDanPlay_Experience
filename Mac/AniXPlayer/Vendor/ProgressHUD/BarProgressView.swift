//
//  BarProgressView.swift
//  ProgressHUD
//
//  水平进度条，对齐 MBBarProgressView
//

import AppKit

class BarProgressView: NSView {

    var progress: Float = 0 {
        didSet { needsDisplay = true }
    }

    var lineColor: NSColor = .white
    var progressRemainingColor: NSColor = .clear
    var progressColor: NSColor = .white

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        return NSSize(width: 120, height: 20)
    }

    override func draw(_ rect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let lineHeight: CGFloat = 2
        let horizontalMargin: CGFloat = 6
        let progressRect = bounds.insetBy(dx: horizontalMargin, dy: (bounds.height - lineHeight) / 2)
        let progressWidth = progressRect.width * CGFloat(max(0, min(1, progress)))

        // Track (remaining)
        context.setFillColor(progressRemainingColor.cgColor)
        context.fill(progressRect)

        // Track border
        context.setStrokeColor(lineColor.cgColor)
        context.setLineWidth(1)
        context.stroke(progressRect)

        // Progress
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
