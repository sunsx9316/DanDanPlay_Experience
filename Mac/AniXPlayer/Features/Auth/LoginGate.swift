//
//  LoginGate.swift
//  AniXPlayer
//
//  macOS only：强制登录的统一入口。
//

import Cocoa

@MainActor
final class LoginGate {
    static let shared = LoginGate()

    private var activeTask: Task<Bool, Never>?
    private var loginWindowController: OAuthLoginWindowController?

    /// 已登录直接返回 true；有 refresh token 先静默恢复；否则弹出登录窗口。
    /// 用户取消返回 false（不抛错）。
    func ensureLoggedIn(presenting window: NSWindow? = nil) async -> Bool {
        if await SessionStore.shared.isLoggedIn() {
            return true
        }

        if let activeTask = activeTask {
            return await activeTask.value
        }

        let task = Task { @MainActor () -> Bool in
            if await SessionStore.shared.restoreIfPossible() {
                return true
            }
            return await self.presentLoginWindow()
        }
        activeTask = task

        let result = await task.value
        activeTask = nil
        return result
    }

    private func presentLoginWindow() async -> Bool {
        await withCheckedContinuation { continuation in
            var resumed = false

            let controller = OAuthLoginWindowController { [weak self] result in
                guard !resumed else { return }
                resumed = true
                self?.loginWindowController = nil

                switch result {
                case .success:
                    continuation.resume(returning: true)
                case .failure:
                    continuation.resume(returning: false)
                }
            }

            loginWindowController = controller
            NSApp.activate(ignoringOtherApps: true)
            controller.showWindow(nil)
            controller.window?.makeKeyAndOrderFront(nil)
        }
    }
}
