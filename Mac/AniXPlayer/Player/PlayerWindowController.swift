//
//  PlayerWindowController.swift
//  AniXPlayer
//
//  macOS：独立播放器窗口。欢迎页/主窗口保持常驻，播放器在单独窗口中运行。
//

import Cocoa
import ANXLog

final class PlayerWindowController: NSWindowController, NSWindowDelegate {

    /// 强引用播放器；窗口关闭后由 MainViewController 释放本控制器。
    let playerViewController: PlayerViewController

    /// 窗口关闭回调；此时 playerViewController 仍然有效，可读取进度。
    var onClose: (() -> Void)?

    private var normalWindowFrame: NSRect?
    private var isPictureInPictureActive = false
    private let normalMinSize = NSSize(width: 640, height: 360)
    private let pipSize = NSSize(width: 800, height: 450)

    init(playerViewController: PlayerViewController) {
        self.playerViewController = playerViewController

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = NSLocalizedString("播放器", comment: "")
        window.minSize = normalMinSize
        window.collectionBehavior = [.fullScreenPrimary]
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.setAccessibilityIdentifier(AccessibilityID.Player.window)
        window.setAccessibilityLabel(NSLocalizedString("播放器窗口", comment: ""))

        super.init(window: window)

        window.delegate = self
        window.contentViewController = playerViewController

        // 关闭窗口时更新标题；weak self 避免窗口控制器与播放器循环引用。
        playerViewController.onMediaChanged = { [weak self] file in
            guard let self = self else { return }
            let title = file?.fileName ?? NSLocalizedString("播放器", comment: "")
            self.window?.title = title
            self.window?.setAccessibilityLabel(title)
            ANX.logInfo(.UI, "[PlayerWindow] 标题更新: \(title)")
        }

        // 复用播放器现有的「画中画」开关：打开时把窗口切换为置顶小窗，关闭时还原。
        playerViewController.playerModel.mediaModel.onPiPToggleChanged = { [weak self] enabled in
            self?.setPictureInPicture(enabled)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        playerViewController.onMediaChanged = nil
        playerViewController.playerModel.mediaModel.onPiPToggleChanged = nil
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        focusPlayer()
        restorePictureInPicturePreferenceIfNeeded()
    }

    /// 让播放器窗口成为 key window，并把第一响应者交给播放器，确保空格等快捷键可用。
    func focusPlayer() {
        guard let window = self.window else { return }
        window.makeKeyAndOrderFront(nil)
        window.initialFirstResponder = playerViewController.view
        if !window.makeFirstResponder(playerViewController) {
            window.makeFirstResponder(playerViewController.view)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Picture in Picture

    /// 把播放器窗口切换为置顶小窗（复用播放器设置中的「画中画」开关）。
    func setPictureInPicture(_ enabled: Bool) {
        guard let window = self.window else { return }
        if enabled == isPictureInPictureActive { return }

        if enabled {
            guard !window.styleMask.contains(.fullScreen) else {
                ANX.logInfo(.UI, "[PlayerWindow] 全屏状态下暂不进入画中画")
                return
            }
            normalWindowFrame = window.frame
            isPictureInPictureActive = true

            window.minSize = NSSize(width: 640, height: 360)
            window.level = .floating
            window.collectionBehavior.insert(.canJoinAllSpaces)
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true

            let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
            let margin: CGFloat = 16
            let target = NSRect(
                x: screenFrame.maxX - pipSize.width - margin,
                y: screenFrame.minY + margin,
                width: pipSize.width,
                height: pipSize.height
            )
            window.setFrame(target, display: true, animate: true)
            window.makeKeyAndOrderFront(nil)
            focusPlayer()
            ANX.logInfo(.UI, "[PlayerWindow] 进入画中画")
        } else {
            isPictureInPictureActive = false
            window.minSize = normalMinSize
            window.level = .normal
            window.collectionBehavior.remove(.canJoinAllSpaces)
            window.titleVisibility = .visible
            window.titlebarAppearsTransparent = false
            window.isMovableByWindowBackground = false

            if let frame = normalWindowFrame {
                window.setFrame(frame, display: true, animate: true)
            }
            normalWindowFrame = nil
            ANX.logInfo(.UI, "[PlayerWindow] 退出画中画")
        }
    }

    /// 窗口展示时恢复用户上次的画中画偏好（只对已加载的播放器生效）。
    private func restorePictureInPicturePreferenceIfNeeded() {
        guard playerViewController.playerModel.mediaModel.playerPiP else { return }
        DispatchQueue.main.async { [weak self] in
            self?.setPictureInPicture(true)
        }
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        ANX.logInfo(.UI, "[PlayerWindow] 关闭播放器窗口")
        // 先让 MainViewController 读取当前进度，再停止播放（stop 可能清空位置）。
        onClose?()
        // 用户直接关闭窗口时也必须停止播放，避免音频在后台继续。
        playerViewController.stopPlayback()
    }
}
