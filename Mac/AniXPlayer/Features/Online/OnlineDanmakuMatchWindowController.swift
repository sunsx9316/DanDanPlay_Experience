//
//  OnlineDanmakuMatchWindowController.swift
//  AniXPlayer
//
//  macOS：在线播放前的「选择弹幕库」窗口。
//
//  只负责窗口生命周期与结果回调；匹配请求和表格在 ViewController 中。
//  关闭窗口（包括点关闭按钮）等同于取消，调用方不会开始播放。
//

import Cocoa

@MainActor
final class OnlineDanmakuMatchWindowController: NSWindowController, NSWindowDelegate {

    private let matchViewController: OnlineDanmakuMatchViewController
    private var completion: ((OnlineDanmakuMatchOutcome) -> Void)?
    private var didFinish = false

    init(initialKeyword: String, completion: @escaping (OnlineDanmakuMatchOutcome) -> Void) {
        let viewController = OnlineDanmakuMatchViewController(initialKeyword: initialKeyword)
        self.matchViewController = viewController
        self.completion = completion

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = NSLocalizedString("选择弹幕库", comment: "")
        window.isReleasedWhenClosed = false
        window.contentViewController = viewController
        window.setAccessibilityIdentifier(AccessibilityID.OnlineDanmakuMatch.window)
        window.setAccessibilityLabel(NSLocalizedString("选择弹幕库窗口", comment: ""))

        super.init(window: window)

        window.delegate = self
        window.center()

        viewController.onFinish = { [weak self] outcome in
            self?.finish(outcome)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 显示窗口；有父窗口时居中到父窗口上，否则使用屏幕中心。
    func present(presenting parentWindow: NSWindow?) {
        guard let window else { return }
        if let parentWindow, parentWindow.isVisible {
            let parentFrame = parentWindow.frame
            let origin = NSPoint(
                x: parentFrame.midX - window.frame.width / 2,
                y: parentFrame.midY - window.frame.height / 2
            )
            window.setFrameOrigin(origin)
        }
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 外部取消（例如在线页开始播放另一集或页面关闭）。
    func cancel() {
        finish(.cancelled)
    }

    private func finish(_ outcome: OnlineDanmakuMatchOutcome) {
        guard !didFinish else { return }
        didFinish = true

        matchViewController.cancelPendingSearch()
        let completion = self.completion
        self.completion = nil
        close()
        completion?(outcome)
    }

    func windowWillClose(_ notification: Notification) {
        matchViewController.cancelPendingSearch()
        guard !didFinish else { return }
        didFinish = true
        let completion = self.completion
        self.completion = nil
        completion?(.cancelled)
    }
}
