//
//  TagCellLayout.swift
//  CocoaShare
//
//  标签 cell 的高度计算：优先使用 contentView 的实际宽度，避免
//  UITableView 把 contentView 缩进 safe area 后仍按 cell 宽度计算。
//

import CoreGraphics

struct TagCellLayout {
    static func contentWidth(
        targetWidth: CGFloat,
        contentViewWidth: CGFloat,
        leftMargin: CGFloat,
        rightMargin: CGFloat
    ) -> CGFloat {
        let width = contentViewWidth > 0 ? contentViewWidth : targetWidth
        return max(0, width - leftMargin - rightMargin)
    }
}
