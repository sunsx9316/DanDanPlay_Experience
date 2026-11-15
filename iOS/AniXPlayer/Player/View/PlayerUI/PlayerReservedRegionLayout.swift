//
//  PlayerReservedRegionLayout.swift
//  AniXPlayer
//
//  根据 Duo 的 fold / camera reserved region 计算播放器控制栏需要让出的空间。
//  纯几何计算，便于独立测试。
//

import CoreGraphics

struct PlayerReservedRegionLayout {

    struct Context {
        var bounds: CGRect
        var divisionRegions: [CGRect]
        var occlusionRegions: [CGRect]
        var topBarHeight: CGFloat
        var bottomBarHeight: CGFloat
        var gap: CGFloat
    }

    struct Result: Equatable {
        var topBarOffset: CGFloat
        var bottomBarOffset: CGFloat
        var leadingInset: CGFloat
        var trailingInset: CGFloat
    }

    static func layout(context: Context) -> Result {
        let bounds = context.bounds
        guard !bounds.isEmpty else {
            return Result(topBarOffset: 0, bottomBarOffset: 0, leadingInset: 0, trailingInset: 0)
        }

        var result = Result(topBarOffset: 0, bottomBarOffset: 0, leadingInset: 0, trailingInset: 0)

        for region in context.divisionRegions where !region.isEmpty {
            if region.width < region.height {
                if region.midX < bounds.midX {
                    result.leadingInset = max(result.leadingInset, region.maxX + context.gap)
                } else {
                    result.trailingInset = max(result.trailingInset, bounds.maxX - region.minX + context.gap)
                }
            } else {
                if region.midY < bounds.midY {
                    result.topBarOffset = max(result.topBarOffset, region.maxY + context.gap)
                } else {
                    result.bottomBarOffset = max(result.bottomBarOffset, bounds.maxY - region.minY + context.gap)
                }
            }
        }

        let topBarRect = CGRect(
            x: bounds.minX,
            y: bounds.minY,
            width: bounds.width,
            height: max(context.topBarHeight, 0)
        )
        let bottomBarRect = CGRect(
            x: bounds.minX,
            y: bounds.maxY - max(context.bottomBarHeight, 0),
            width: bounds.width,
            height: max(context.bottomBarHeight, 0)
        )

        for region in context.occlusionRegions where !region.isEmpty {
            let intersectsBars = region.intersects(topBarRect) || region.intersects(bottomBarRect)
            guard intersectsBars else { continue }

            if region.width < region.height {
                if region.midX < bounds.midX {
                    result.leadingInset = max(result.leadingInset, region.maxX - bounds.minX + context.gap)
                } else {
                    result.trailingInset = max(result.trailingInset, bounds.maxX - region.minX + context.gap)
                }
            } else {
                if region.intersects(topBarRect) {
                    result.topBarOffset = max(result.topBarOffset, region.maxY - bounds.minY + context.gap)
                }
                if region.intersects(bottomBarRect) {
                    result.bottomBarOffset = max(result.bottomBarOffset, bounds.maxY - region.minY + context.gap)
                }
            }
        }

        let topHeight = max(context.topBarHeight, 0)
        let bottomHeight = max(context.bottomBarHeight, 0)
        result.topBarOffset = min(max(0, result.topBarOffset), max(0, bounds.height - topHeight))
        result.bottomBarOffset = min(max(0, result.bottomBarOffset), max(0, bounds.height - bottomHeight))
        result.leadingInset = min(max(0, result.leadingInset), bounds.width)
        result.trailingInset = min(max(0, result.trailingInset), bounds.width)

        return result
    }
}
