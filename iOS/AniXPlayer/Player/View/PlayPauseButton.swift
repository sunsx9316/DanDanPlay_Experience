//
//  PlayPauseButton.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/5/31.
//

import UIKit

class PlayPauseButton: Button {

    enum Style {
        case play
        case pause
    }

    var iconStrokeColor: UIColor = .white {
        didSet {
            lineLayers.forEach { $0.strokeColor = iconStrokeColor.cgColor }
        }
    }

    var iconHighlightStrokeColor: UIColor = .lightGray {
        didSet {
            updateStrokeColor()
        }
    }

    var iconLineWidth: CGFloat = 3 {
        didSet {
            lineLayers.forEach { $0.lineWidth = iconLineWidth }
        }
    }

    var iconStyle: Style = .pause {
        didSet {
            setStyle(iconStyle, animated: false)
        }
    }
    private var currentStyle: Style = .pause
    private let lineCount = 6
    private var lineLayers: [CAShapeLayer] = []

    override var isHighlighted: Bool {
        didSet { updateStrokeColor() }
    }

    override var isEnabled: Bool {
        didSet { updateStrokeColor() }
    }

    func setStyle(_ style: Style, animated: Bool) {
        guard style != currentStyle else { return }
        let fromStyle = currentStyle
        currentStyle = style
        iconStyle = style

        if animated {
            animate(from: fromStyle, to: style)
        } else {
            applyEndpoints(for: style)
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !bounds.isEmpty else { return }
        lineLayers.forEach { $0.frame = bounds }
        applyEndpoints(for: currentStyle)
    }

    // MARK: - Private

    private func setupLayers() {
        for _ in 0..<lineCount {
            let layer = CAShapeLayer()
            layer.fillColor = nil
            layer.lineCap = .round
            layer.lineWidth = iconLineWidth
            layer.strokeColor = iconStrokeColor.cgColor
            self.layer.addSublayer(layer)
            lineLayers.append(layer)
        }
    }

    private func updateStrokeColor() {
        let color = (!isEnabled || isHighlighted) ? iconHighlightStrokeColor : iconStrokeColor
        lineLayers.forEach { $0.strokeColor = color.cgColor }
    }

    private func applyEndpoints(for style: Style) {
        guard !bounds.isEmpty else { return }
        let lines = endpoints(for: style)
        for (index, lineLayer) in lineLayers.enumerated() {
            lineLayer.path = linePath(from: lines[index])
        }
    }

    private func animate(from fromStyle: Style, to toStyle: Style) {
        guard !bounds.isEmpty else { return }
        let fromLines = endpoints(for: fromStyle)
        let toLines = endpoints(for: toStyle)

        for (index, lineLayer) in lineLayers.enumerated() {
            let anim = CABasicAnimation(keyPath: "path")
            anim.fromValue = linePath(from: fromLines[index])
            anim.toValue = linePath(from: toLines[index])
            anim.duration = 0.3
            anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            anim.fillMode = .forwards
            anim.isRemovedOnCompletion = false
            lineLayer.add(anim, forKey: "morph")
        }

        applyEndpoints(for: toStyle)
    }

    private func linePath(from line: Line) -> CGPath {
        let path = CGMutablePath()
        path.move(to: line.start)
        path.addLine(to: line.end)
        return path
    }

    // MARK: - Line Definitions

    private struct Line {
        let start: CGPoint
        let end: CGPoint
    }

    private func endpoints(for style: Style) -> [Line] {
        let rect = bounds
        guard !rect.isEmpty else {
            return Array(repeating: Line(start: .zero, end: .zero), count: lineCount)
        }
        switch style {
        case .play:
            return playEndpoints(in: rect)
        case .pause:
            return pauseEndpoints(in: rect)
        }
    }

    /// 6 条线段组成右指三角形，三条边各 2 段
    private func playEndpoints(in rect: CGRect) -> [Line] {
        let left: CGFloat = 0.18
        let right: CGFloat = 0.88
        let top: CGFloat = 0.18
        let bottom: CGFloat = 0.82
        let midY: CGFloat = 0.5

        // 三角形三个顶点
        let pTopLeft = point(x: left, y: top, in: rect)
        let pBottomLeft = point(x: left, y: bottom, in: rect)
        let pRight = point(x: right, y: midY, in: rect)

        // 左边竖线中点
        let leftMid = point(x: left, y: (top + bottom) / 2, in: rect)

        // 上斜边中点
        let topDiagMid = point(x: (left + right) / 2, y: (top + midY) / 2, in: rect)

        // 下斜边中点
        let botDiagMid = point(x: (left + right) / 2, y: (midY + bottom) / 2, in: rect)

        return [
            // 左边竖线 (2 段)
            Line(start: pTopLeft, end: leftMid),
            Line(start: leftMid, end: pBottomLeft),
            // 上斜边 (2 段)
            Line(start: pTopLeft, end: topDiagMid),
            Line(start: topDiagMid, end: pRight),
            // 下斜边 (2 段)
            Line(start: pRight, end: botDiagMid),
            Line(start: botDiagMid, end: pBottomLeft),
        ]
    }

    /// 6 条线段组成两个竖线（暂停图标）
    private func pauseEndpoints(in rect: CGRect) -> [Line] {
        let leftBarX: CGFloat = 0.22
        let rightBarX: CGFloat = 0.68
        let top: CGFloat = 0.18
        let bottom: CGFloat = 0.82

        // 左竖线拆成 3 段
        let l1 = point(x: leftBarX, y: top, in: rect)
        let l2 = point(x: leftBarX, y: top + (bottom - top) / 3, in: rect)
        let l3 = point(x: leftBarX, y: top + (bottom - top) * 2 / 3, in: rect)
        let l4 = point(x: leftBarX, y: bottom, in: rect)

        // 右竖线拆成 3 段
        let r1 = point(x: rightBarX, y: top, in: rect)
        let r2 = point(x: rightBarX, y: top + (bottom - top) / 3, in: rect)
        let r3 = point(x: rightBarX, y: top + (bottom - top) * 2 / 3, in: rect)
        let r4 = point(x: rightBarX, y: bottom, in: rect)

        return [
            Line(start: l1, end: l2),
            Line(start: l2, end: l3),
            Line(start: l3, end: l4),
            Line(start: r1, end: r2),
            Line(start: r2, end: r3),
            Line(start: r3, end: r4),
        ]
    }

    private func point(x: CGFloat, y: CGFloat, in rect: CGRect) -> CGPoint {
        return CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
    }
}
