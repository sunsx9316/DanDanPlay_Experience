//
//  UIView+HitTest.swift
//  AniXPlayer
//
//  扩大 UIView 点击区域 — 负值向外扩展
//

#if os(iOS) || os(tvOS)
import UIKit

extension UIView {

    private struct HitTestAssociatedKeys {
        static var slop: UInt8 = 0
    }

    private static let _swizzlePointInside: Void = {
        let originalSelector = #selector(point(inside:with:))
        let swizzledSelector = #selector(anx_pointInside(_:with:))

        guard let originalMethod = class_getInstanceMethod(UIView.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(UIView.self, swizzledSelector) else {
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }()

    /// 扩大点击区域，负值向外扩展
    /// 例：`view.hitTestSlop = UIEdgeInsets(top: -10, left: -10, bottom: -10, right: -10)` 四周扩大 10pt
    var hitTestSlop: UIEdgeInsets {
        get {
            _ = Self._swizzlePointInside
            return objc_getAssociatedObject(self, &HitTestAssociatedKeys.slop) as? UIEdgeInsets ?? .zero
        }
        set {
            _ = Self._swizzlePointInside
            objc_setAssociatedObject(self, &HitTestAssociatedKeys.slop, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    @objc private func anx_pointInside(_ point: CGPoint, with event: UIEvent?) -> Bool {
        let slop = hitTestSlop
        if slop == .zero {
            return anx_pointInside(point, with: event)
        }
        return bounds.inset(by: slop).contains(point)
    }
}
#endif
