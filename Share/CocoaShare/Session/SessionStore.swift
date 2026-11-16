//
//  SessionStore.swift
//  AniXPlayer
//
//  macOS only：登录会话状态机。
//
//  - access token 只在内存；refresh token 只进 Keychain；
//  - refresh 单飞：并发请求共享同一个刷新 Task；
//  - refresh_token 轮换：Keychain 写入失败视为会话失效（避免旧 token 已失效但本地还在用新 token）。
//

import Foundation

actor SessionStore {
    static let shared = SessionStore()

    enum State: Equatable {
        case loggedOut
        case restoring
        case loggedIn
        case refreshing
    }

    enum SessionError: LocalizedError {
        case notLoggedIn
        case tokenStorage(Error)

        var errorDescription: String? {
            switch self {
            case .notLoggedIn:
                return NSLocalizedString("登录已过期，请重新登录", comment: "")
            case .tokenStorage:
                return NSLocalizedString("无法安全保存登录信息，请检查钥匙串权限", comment: "")
            }
        }
    }

    private(set) var state: State = .loggedOut
    private(set) var profile: OAuthUserProfile?

    private var token: OAuthToken?
    private var refreshTask: Task<OAuthToken, Error>?
    private var restoreTask: Task<Bool, Never>?

    private let service: OAuthServicing
    private let tokenStore: RefreshTokenStore
    private let accessTokenHolder: AccessTokenHolder

    init(
        service: OAuthServicing = OAuthService(),
        tokenStore: RefreshTokenStore = KeychainRefreshTokenStore(),
        accessTokenHolder: AccessTokenHolder = .shared
    ) {
        self.service = service
        self.tokenStore = tokenStore
        self.accessTokenHolder = accessTokenHolder
    }

    // MARK: - Read

    func currentState() -> State {
        state
    }

    func currentProfile() -> OAuthUserProfile? {
        profile
    }

    func isLoggedIn() -> Bool {
        state == .loggedIn
    }

    func currentToken() -> OAuthToken? {
        token
    }

    // MARK: - Restore

    /// 冷启动时用 Keychain 中的 refresh token 静默恢复。
    /// 网络失败不清 refresh token；只有 invalid_grant / 凭证问题才清会话。
    func restoreIfPossible() async -> Bool {
        if state == .loggedIn {
            return true
        }

        // 静默恢复单飞：启动引导与登录门禁可能同时调用。
        if let task = restoreTask {
            return await task.value
        }

        let task = Task { () -> Bool in
            await self.performRestore()
        }
        restoreTask = task

        let result = await task.value
        restoreTask = nil
        return result
    }

    private func performRestore() async -> Bool {
        switch state {
        case .loggedIn:
            return true
        case .restoring, .refreshing:
            return false
        case .loggedOut:
            break
        }

        guard let refreshToken = (try? tokenStore.readRefreshToken()) ?? nil, !refreshToken.isEmpty else {
            setState(.loggedOut)
            return false
        }

        setState(.restoring)
        do {
            let newToken = try await performRefresh(refreshToken: refreshToken)
            apply(newToken)

            if let profile = try? await service.fetchProfile(accessToken: newToken.accessToken) {
                self.profile = profile
            }
            setState(.loggedIn)
            return true
        } catch {
            if isSessionInvalidating(error) {
                clearSession()
            } else {
                clearMemory()
                setState(.loggedOut)
            }
            return false
        }
    }

    // MARK: - Sign in / out

    func signIn(code: String, transaction: OAuthTransaction) async throws {
        let newToken = try await service.exchangeCode(code, transaction: transaction)

        do {
            try tokenStore.saveRefreshToken(newToken.refreshToken)
        } catch {
            throw SessionError.tokenStorage(error)
        }

        apply(newToken)
        profile = try? await service.fetchProfile(accessToken: newToken.accessToken)
        setState(.loggedIn)
        notifyChanged()
    }

    func logout() async {
        let accessToken = token?.accessToken
        let refreshToken = (try? tokenStore.readRefreshToken()) ?? nil

        clearSession()

        if let accessToken = accessToken, !accessToken.isEmpty {
            await service.logout(accessToken: accessToken)
        }
        if let refreshToken = refreshToken, !refreshToken.isEmpty {
            await service.revoke(refreshToken: refreshToken)
        }
    }

    // MARK: - Token access

    /// 供业务请求使用：提前 5 分钟刷新；并发调用共享同一次刷新。
    func validAccessToken() async throws -> String {
        if let token = token, !token.isExpiring() {
            return token.accessToken
        }
        let refreshed = try await forceRefresh()
        return refreshed.accessToken
    }

    func forceRefresh() async throws -> OAuthToken {
        if let task = refreshTask {
            let newToken = try await task.value
            apply(newToken)
            if state == .refreshing {
                setState(.loggedIn)
            }
            return newToken
        }

        guard let refreshToken = (try? tokenStore.readRefreshToken()) ?? nil, !refreshToken.isEmpty else {
            clearSession()
            throw SessionError.notLoggedIn
        }

        let previousState = state
        setState(.refreshing)

        let task = Task { [service, tokenStore] () throws -> OAuthToken in
            let newToken = try await service.refresh(refreshToken: refreshToken)
            do {
                try tokenStore.saveRefreshToken(newToken.refreshToken)
            } catch {
                throw SessionError.tokenStorage(error)
            }
            return newToken
        }
        refreshTask = task

        do {
            let newToken = try await task.value
            refreshTask = nil
            apply(newToken)
            setState(.loggedIn)
            return newToken
        } catch {
            refreshTask = nil
            if isSessionInvalidating(error) {
                clearSession()
            } else {
                setState(previousState == .loggedOut ? .loggedOut : .loggedIn)
            }
            throw error
        }
    }

    /// 重新拉取 `/user/me`（支付成功、修改资料后调用）。
    func refreshProfile() async throws {
        guard let token = token else {
            throw SessionError.notLoggedIn
        }
        let newProfile = try await service.fetchProfile(accessToken: token.accessToken)
        self.profile = newProfile
        notifyChanged()
    }

    // MARK: - Private

    private func performRefresh(refreshToken: String) async throws -> OAuthToken {
        let newToken = try await service.refresh(refreshToken: refreshToken)
        do {
            try tokenStore.saveRefreshToken(newToken.refreshToken)
        } catch {
            throw SessionError.tokenStorage(error)
        }
        return newToken
    }

    private func apply(_ token: OAuthToken) {
        self.token = token
        accessTokenHolder.set(token.accessToken)
    }

    private func clearSession() {
        clearMemory()
        try? tokenStore.deleteRefreshToken()
        setState(.loggedOut)
    }

    private func clearMemory() {
        token = nil
        profile = nil
        accessTokenHolder.set(nil)
        refreshTask?.cancel()
        refreshTask = nil
    }

    /// 是否属于「本地会话已不可用」：invalid_grant、401/403 凭证问题、Keychain 写入失败。
    private func isSessionInvalidating(_ error: Error) -> Bool {
        if case SessionStore.SessionError.tokenStorage = error {
            return true
        }
        if let apiError = error as? APIError {
            return apiError.isInvalidGrant || apiError.isCredentialFailure
        }
        return false
    }

    private func setState(_ newState: State) {
        let changed = state != newState
        state = newState
        if changed {
            notifyChanged()
        }
    }

    private func notifyChanged() {
        Task { @MainActor in
            NotificationCenter.default.post(name: .AnixUserLoginStateDidChange, object: nil)
        }
    }
}
