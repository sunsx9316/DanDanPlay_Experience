//
//  MacAuthBootstrap.swift
//  AniXPlayer
//
//  macOS only：启动时切换网络认证方式并恢复会话。
//

import Foundation

enum MacAuthBootstrap {
    /// 必须在任何在线请求发出前调用。
    static func start() {
        // macOS 从第一天起「强制登录 + 纯 Bearer」：不发送 X-AppId/X-Signature。
        NetworkManager.shared.bearerTokenProvider = {
            AccessTokenHolder.shared.current()
        }
        NetworkManager.shared.appSignatureEnabled = false

        // 旧 JWT 不迁移、不复用，按泄漏处理；macOS 用户需要重新登录一次。
        if Preferences.shared.loginInfo != nil {
            Preferences.shared.loginInfo = nil
        }

        Task {
            _ = await SessionStore.shared.restoreIfPossible()
        }
    }

    /// 首启/未登录时展示登录窗口；取消后仍可使用本地播放。
    static func presentLoginIfNeeded() {
        Task { @MainActor in
            _ = await LoginGate.shared.ensureLoggedIn()
        }
    }
}
