//
//  TextField.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/10.
//

import Cocoa

// MARK: - VerticallyCenteredTextFieldCell

fileprivate class VerticallyCenteredTextFieldCell: NSTextFieldCell {

    var verticallyCentered: Bool = false
    var horizontalPadding: CGFloat = 4

    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        var newRect = super.drawingRect(forBounds: rect)
        newRect = applyHorizontalPadding(to: newRect)
        newRect = applyVerticalCentering(to: newRect)
        return newRect
    }

    override func edit(withFrame rect: NSRect, in controlView: NSView, editor text: NSText, delegate: Any?, event: NSEvent?) {
        var adjustedRect = rect
        adjustedRect = applyHorizontalPadding(to: adjustedRect)
        adjustedRect = applyVerticalCentering(to: adjustedRect)
        super.edit(withFrame: adjustedRect, in: controlView, editor: text, delegate: delegate, event: event)
    }

    override func select(withFrame rect: NSRect, in controlView: NSView, editor text: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        var adjustedRect = rect
        adjustedRect = applyHorizontalPadding(to: adjustedRect)
        adjustedRect = applyVerticalCentering(to: adjustedRect)
        super.select(withFrame: adjustedRect, in: controlView, editor: text, delegate: delegate, start: selStart, length: selLength)
    }

    private func applyHorizontalPadding(to rect: NSRect) -> NSRect {
        guard isEditable, horizontalPadding > 0 else { return rect }
        var r = rect
        r.origin.x += horizontalPadding
        r.size.width -= horizontalPadding * 2
        return r
    }

    private func applyVerticalCentering(to rect: NSRect) -> NSRect {
        guard verticallyCentered else { return rect }
        var r = rect
        let textSize = cellSize(forBounds: r)
        let heightDelta = r.size.height - textSize.height
        if heightDelta > 0 {
            r.size.height = textSize.height
            r.origin.y += heightDelta / 2
        }
        return r
    }
}

// MARK: - VerticallyCenteredSecureTextFieldCell

fileprivate class VerticallyCenteredSecureTextFieldCell: NSSecureTextFieldCell {

    var verticallyCentered: Bool = false
    var horizontalPadding: CGFloat = 4

    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        var newRect = super.drawingRect(forBounds: rect)
        newRect = applyHorizontalPadding(to: newRect)
        newRect = applyVerticalCentering(to: newRect)
        return newRect
    }

    override func edit(withFrame rect: NSRect, in controlView: NSView, editor text: NSText, delegate: Any?, event: NSEvent?) {
        var adjustedRect = rect
        adjustedRect = applyHorizontalPadding(to: adjustedRect)
        adjustedRect = applyVerticalCentering(to: adjustedRect)
        super.edit(withFrame: adjustedRect, in: controlView, editor: text, delegate: delegate, event: event)
    }

    override func select(withFrame rect: NSRect, in controlView: NSView, editor text: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        var adjustedRect = rect
        adjustedRect = applyHorizontalPadding(to: adjustedRect)
        adjustedRect = applyVerticalCentering(to: adjustedRect)
        super.select(withFrame: adjustedRect, in: controlView, editor: text, delegate: delegate, start: selStart, length: selLength)
    }

    private func applyHorizontalPadding(to rect: NSRect) -> NSRect {
        guard isEditable, horizontalPadding > 0 else { return rect }
        var r = rect
        r.origin.x += horizontalPadding
        r.size.width -= horizontalPadding * 2
        return r
    }

    private func applyVerticalCentering(to rect: NSRect) -> NSRect {
        guard verticallyCentered else { return rect }
        var r = rect
        let textSize = cellSize(forBounds: r)
        let heightDelta = r.size.height - textSize.height
        if heightDelta > 0 {
            r.size.height = textSize.height
            r.origin.y += heightDelta / 2
        }
        return r
    }
}

// MARK: - TextField

class TextField: NSTextField {

    var centersVertically: Bool = false {
        didSet {
            (cell as? VerticallyCenteredTextFieldCell)?.verticallyCentered = centersVertically
        }
    }

    var horizontalPadding: CGFloat = 4 {
        didSet {
            (cell as? VerticallyCenteredTextFieldCell)?.horizontalPadding = horizontalPadding
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.setupInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setupInit()
    }

    private func setupInit() {
        self.font = .ddp_normal
        self.textColor = .textColor
        self.drawsBackground = true
        self.backgroundColor = .textBackgroundColor
        let cell = VerticallyCenteredTextFieldCell(textCell: "")
        cell.isEditable = true
        cell.isSelectable = true
        cell.horizontalPadding = horizontalPadding
        self.cell = cell
    }

}

// MARK: - SecureTextField

class SecureTextField: NSSecureTextField {

    var centersVertically: Bool = false {
        didSet {
            (cell as? VerticallyCenteredSecureTextFieldCell)?.verticallyCentered = centersVertically
        }
    }

    var horizontalPadding: CGFloat = 4 {
        didSet {
            (cell as? VerticallyCenteredSecureTextFieldCell)?.horizontalPadding = horizontalPadding
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.setupInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setupInit()
    }

    private func setupInit() {
        self.font = .ddp_normal
        self.textColor = .textColor
        self.drawsBackground = true
        self.backgroundColor = .textBackgroundColor
        let cell = VerticallyCenteredSecureTextFieldCell(textCell: "")
        cell.isEditable = true
        cell.isSelectable = true
        cell.horizontalPadding = horizontalPadding
        self.cell = cell
    }

}

// MARK: - Label

class Label: TextField {

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.setupInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setupInit()
    }

    // MARK: - Private

    private func setupInit() {
        self.isEditable = false
        self.isBordered = false
        self.drawsBackground = false
        self.horizontalPadding = 0
    }
}
