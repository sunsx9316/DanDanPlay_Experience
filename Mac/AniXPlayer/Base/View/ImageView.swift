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
            guard currentScaling == .aspectFill else { return }
            wantsLayer = true
            layer?.contentsGravity = .resizeAspectFill
            layer?.masksToBounds = true
        }
    }

    override var image: NSImage? {
        didSet {
            guard currentScaling == .aspectFill, let img = image else { return }
            layer?.contents = img
        }
    }

    // MARK: - Public

    /// 预设缩放模式（本地图片后续直接设 .image，远程图片用 Kingfisher 等异步加载）
    func setScaling(_ scaling: ImageScaling) {
        currentScaling = scaling
        imageScaling = scaling.nsImageScaling
    }
}
