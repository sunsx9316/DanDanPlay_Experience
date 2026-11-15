//
//  PlayerControlPanelLayout.swift
//  AniXPlayer
//
//  播放器侧边面板的纯宽度计算：宽度永远不超过容器，窄窗口下也不会把关闭入口挤出屏幕。
//

import CoreGraphics

struct PlayerControlPanelLayout {
    static let widthRatio: CGFloat = 0.5
    static let minWidth: CGFloat = 320
    static let maxWidth: CGFloat = 420

    static func width(containerWidth: CGFloat) -> CGFloat {
        guard containerWidth > 0 else { return 0 }
        return min(max(containerWidth * widthRatio, minWidth), maxWidth, containerWidth)
    }
}
