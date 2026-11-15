//
//  TagFlowLayout.swift
//  CocoaShare
//
//  纯标签流式布局引擎：只依赖 CoreGraphics，方便 iOS/tvOS 共用和独立测试。
//

import CoreGraphics

struct TagFlowLayout {
    struct Metrics {
        var horizontalSpacing: CGFloat
        var verticalSpacing: CGFloat
    }

    enum LayoutDirection {
        case leftToRight
        case rightToLeft
    }

    struct Result {
        var frames: [CGRect]
        var contentHeight: CGFloat
    }

    static func layout(
        sizes: [CGSize],
        in width: CGFloat,
        metrics: Metrics,
        layoutDirection: LayoutDirection = .leftToRight
    ) -> Result {
        guard width > 0, !sizes.isEmpty else {
            return Result(frames: [], contentHeight: 0)
        }

        var frames: [CGRect] = []
        frames.reserveCapacity(sizes.count)

        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for size in sizes {
            let itemWidth = max(size.width, 0)
            let itemHeight = max(size.height, 0)

            if x > 0, x + itemWidth > width {
                x = 0
                y += rowHeight + metrics.verticalSpacing
                rowHeight = 0
            }

            let originX: CGFloat
            switch layoutDirection {
            case .leftToRight:
                originX = x
            case .rightToLeft:
                originX = width - x - itemWidth
            }

            frames.append(CGRect(x: originX, y: y, width: itemWidth, height: itemHeight))
            x += itemWidth + metrics.horizontalSpacing
            rowHeight = max(rowHeight, itemHeight)
        }

        return Result(frames: frames, contentHeight: y + rowHeight)
    }
}
