//
//  ThemedTableRowView.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/3.
//

import Cocoa

/// 使用 App 主题色绘制选中高亮的 NSTableRowView
class ThemedTableRowView: NSTableRowView {

    var isHovered: Bool = false {
        didSet {
            if oldValue != isHovered {
                needsDisplay = true
            }
        }
    }

    override func drawBackground(in dirtyRect: NSRect) {
        super.drawBackground(in: dirtyRect)
        if isHovered, !isSelected {
            NSColor.mainColor.withAlphaComponent(0.06).setFill()
            let cornerRadius: CGFloat = 4
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 0), xRadius: cornerRadius, yRadius: cornerRadius)
            path.fill()
        }
    }

    override func drawSelection(in dirtyRect: NSRect) {
        guard selectionHighlightStyle != .none else { return }

        let color = NSColor.mainColor
        let alpha: CGFloat = isEmphasized ? 0.24 : 0.12
        color.withAlphaComponent(alpha).setFill()

        let cornerRadius: CGFloat = 4
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 0), xRadius: cornerRadius, yRadius: cornerRadius)
        path.fill()
    }

    override var isEmphasized: Bool {
        didSet {
            needsDisplay = true
        }
    }
}

// MARK: - Hover Tracker

private var hoverTrackerKey: UInt8 = 0

private class TableHoverTracker: NSObject {
    weak var tableView: NSTableView?

    init(tableView: NSTableView) {
        self.tableView = tableView
        super.init()
        let area = NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil)
        tableView.addTrackingArea(area)
    }

    @objc(mouseMoved:) func mouseMoved(_ event: NSEvent) {
        guard let tableView = tableView else { return }
        let point = tableView.convert(event.locationInWindow, from: nil)
        let hoveredRow = tableView.row(at: point)
        updateHover(for: tableView, hoveredRow: hoveredRow)
    }

    @objc(mouseEntered:) func mouseEntered(_ event: NSEvent) {
        guard let tableView = tableView else { return }
        let point = tableView.convert(event.locationInWindow, from: nil)
        let hoveredRow = tableView.row(at: point)
        updateHover(for: tableView, hoveredRow: hoveredRow)
    }

    @objc(mouseExited:) func mouseExited(_ event: NSEvent) {
        guard let tableView = tableView else { return }
        updateHover(for: tableView, hoveredRow: -1)
    }

    private func updateHover(for tableView: NSTableView, hoveredRow: Int) {
        let count = tableView.numberOfRows
        for i in 0..<count {
            if let rowView = tableView.rowView(atRow: i, makeIfNecessary: false) as? ThemedTableRowView {
                rowView.isHovered = (i == hoveredRow && i >= 0)
            }
        }
    }
}

// MARK: - NSTableView Extension

extension NSTableView {
    func themedRowView(forRow row: Int) -> NSTableRowView {
        let identifier = NSUserInterfaceItemIdentifier("ThemedRowView")
        if let rowView = makeView(withIdentifier: identifier, owner: nil) as? ThemedTableRowView {
            return rowView
        }
        let rowView = ThemedTableRowView()
        rowView.identifier = identifier
        return rowView
    }

    /// 启用 row hover 高亮追踪
    func enableRowHoverTracking() {
        if objc_getAssociatedObject(self, &hoverTrackerKey) != nil { return }
        let tracker = TableHoverTracker(tableView: self)
        objc_setAssociatedObject(self, &hoverTrackerKey, tracker, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
