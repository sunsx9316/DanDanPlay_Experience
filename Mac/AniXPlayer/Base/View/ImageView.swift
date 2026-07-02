//
//  ImageView.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/12.
//

import Cocoa

/// 图片缩放模式，对应 NSImageScaling 全部四类 + aspectFill
enum ImageScaling {
    case none
    case scaleToFill
    case aspectFit
    case aspectFill
    case proportionallyDown

    fileprivate var nsImageScaling: NSImageScaling {
        switch self {
        case .none:                 return .scaleNone
        case .scaleToFill:          return .scaleAxesIndependently
        case .aspectFit:            return .scaleProportionallyUpOrDown
        case .proportionallyDown:   return .scaleProportionallyDown
        case .aspectFill:           return .scaleNone
        }
    }
}

class ImageView: NSImageView {

    private var currentScaling: ImageScaling = .none {
        didSet {
            if currentScaling == .aspectFill {
                wantsLayer = true
                layer?.masksToBounds = true
            } else {
                layer?.masksToBounds = false
            }
        }
    }

    override var image: NSImage? {
        didSet {
            if currentScaling == .aspectFill {
                needsDisplay = true
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard currentScaling == .aspectFill, let image = image else {
            super.draw(dirtyRect)
            return
        }

        let viewSize = bounds.size
        let imageSize = image.size

        guard viewSize.width > 0, viewSize.height > 0,
              imageSize.width > 0, imageSize.height > 0 else {
            return
        }

        let viewAspect = viewSize.width / viewSize.height
        let imageAspect = imageSize.width / imageSize.height

        var drawRect: NSRect
        if imageAspect > viewAspect {
            let drawWidth = viewSize.height * imageAspect
            drawRect = NSRect(x: (viewSize.width - drawWidth) / 2, y: 0,
                              width: drawWidth, height: viewSize.height)
        } else {
            let drawHeight = viewSize.width / imageAspect
            drawRect = NSRect(x: 0, y: (viewSize.height - drawHeight) / 2,
                              width: viewSize.width, height: drawHeight)
        }

        image.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    // MARK: - Public

    /// 预设缩放模式（本地图片后续直接设 .image，远程图片用 Kingfisher 等异步加载）
    func setScaling(_ scaling: ImageScaling) {
        currentScaling = scaling
        imageScaling = scaling.nsImageScaling
    }
}
