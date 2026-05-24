//
//  PlayerOverlayView.swift
//  AniXPlayer
//
//  tvOS 播放器控制浮层 — 包含顶部标题栏 + 底部进度栏，统一管理显隐动画
//

import UIKit
import SnapKit

class PlayerOverlayView: UIView {

    // MARK: - Subviews

    let topBar = PlayerUITopView()
    let bottomBar = PlayerUIBottomView()

    // MARK: - State (直接读 view 状态，不加额外变量)

    var isVisible: Bool { alpha > 0 }
    var autoHideDuration: TimeInterval = 4
    var onAutoHide: (() -> Void)?
    var onShow: (() -> Void)?
    var onHide: (() -> Void)?

    private var autoHideTimer: Timer?
    private let topBarHeight: CGFloat = 80
    private let bottomBarHeight: CGFloat = 100

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(topBar)
        addSubview(bottomBar)

        topBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview()
            make.height.equalTo(topBarHeight)
        }

        bottomBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
            make.height.equalTo(bottomBarHeight)
        }

        // 初始隐藏
        alpha = 0
        topBar.transform = CGAffineTransform(translationX: 0, y: -topBarHeight)
        bottomBar.transform = CGAffineTransform(translationX: 0, y: bottomBarHeight)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Show / Hide

    func show() {
        guard !isVisible else { return }

        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            self.alpha = 1
            self.topBar.transform = .identity
            self.bottomBar.transform = .identity
        } completion: { _ in
            self.onShow?()
        }

        resetAutoHideTimer()
    }

    func hide() {
        guard isVisible else { return }

        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            self.alpha = 0
            self.topBar.transform = CGAffineTransform(translationX: 0, y: -self.topBarHeight)
            self.bottomBar.transform = CGAffineTransform(translationX: 0, y: self.bottomBarHeight)
        } completion: { _ in
            self.onHide?()
        }

        autoHideTimer?.invalidate()
        autoHideTimer = nil
    }

    func resetAutoHideTimer() {
        autoHideTimer?.invalidate()
        guard isVisible else { return }
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: autoHideDuration, repeats: false) { [weak self] _ in
            self?.onAutoHide?()
        }
    }
}
