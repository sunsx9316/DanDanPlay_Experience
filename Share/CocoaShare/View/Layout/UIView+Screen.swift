//
//  UIView+Screen.swift
//  CocoaShare
//
//  从当前窗口场景读取屏幕信息，避免依赖 UIScreen.main。
//

#if os(iOS) || os(tvOS)
import UIKit

extension UIView {
    /// 当前窗口所在的屏幕。窗口/场景变化时重新读取，不缓存。
    var anxScreen: UIScreen? {
        window?.windowScene?.screen
    }

    /// 当前屏幕缩放。优先窗口所在屏幕，回退到本地 trait collection。
    var anxScreenScale: CGFloat {
        anxScreen?.scale ?? traitCollection.displayScale
    }
}
#endif
