//
//  AccountProfileViewModel.swift
//  AniXPlayer
//
//  macOS only：账号资料窗口的状态与操作编排。
//

import AppKit
import Foundation

enum AccountProfileStatusTone {
    case info
    case success
    case error
}

struct AccountProfileStatusMessage: Equatable {
    let text: String
    let tone: AccountProfileStatusTone
}

@MainActor
final class AccountProfileViewModel {

    private enum RefreshAfterMutationResult {
        case refreshed
        case signedOut
        case failed
    }

    private(set) var isLoggedIn = false
    private(set) var profile: OAuthUserProfile?
    private(set) var isRefreshing = false
    private(set) var isSubmitting = false
    private(set) var statusMessage: AccountProfileStatusMessage?
    private(set) var pendingExternalRefresh = false

    var onUpdate: (() -> Void)?

    private let service: AccountProfileServicing
    private let session: SessionStore
    private let openURL: (URL) -> Void

    init(
        service: AccountProfileServicing = AccountProfileService(),
        session: SessionStore = .shared,
        openURL: @escaping (URL) -> Void = { NSWorkspace.shared.open($0) }
    ) {
        self.service = service
        self.session = session
        self.openURL = openURL
    }

    // MARK: - Derived state

    var bangumiState: AccountBangumiLinkState {
        AccountBangumiLinkState(account: profile?.bangumiAccount)
    }

    var canEdit: Bool {
        isLoggedIn && !isSubmitting
    }

    var emailDisplayText: String {
        guard let email = profile?.email, !email.isEmpty else {
            return NSLocalizedString("未设置邮箱", comment: "")
        }
        return email
    }

    var emailVerificationText: String {
        guard let email = profile?.email, !email.isEmpty else { return "" }
        return profile?.emailVerified == true
            ? NSLocalizedString("邮箱已验证", comment: "")
            : NSLocalizedString("邮箱未验证", comment: "")
    }

    var memberStatusText: String {
        guard let memberDate = profile?.privileges?.member else {
            return NSLocalizedString("未开通会员", comment: "")
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if memberDate > Date() {
            return String(
                format: NSLocalizedString("会员有效期至 %@", comment: ""),
                formatter.string(from: memberDate)
            )
        }
        return String(
            format: NSLocalizedString("会员已过期（%@）", comment: ""),
            formatter.string(from: memberDate)
        )
    }

    // MARK: - Lifecycle

    func reloadSession() async {
        let loggedIn = await session.isLoggedIn()
        let currentProfile = await session.currentProfile()
        isLoggedIn = loggedIn
        profile = currentProfile

        if loggedIn && currentProfile == nil {
            await refreshProfile(silent: true)
            return
        }
        onUpdate?()
    }

    func refreshProfile(silent: Bool = false) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        onUpdate?()
        defer {
            isRefreshing = false
            onUpdate?()
        }

        do {
            _ = try await session.validAccessToken()
            try await session.refreshProfile()
            isLoggedIn = await session.isLoggedIn()
            profile = await session.currentProfile()
            if !silent {
                setStatus(NSLocalizedString("资料已刷新", comment: ""), tone: .success)
            }
        } catch {
            await handleRefreshFailure(error, silent: silent)
        }
    }

    func consumePendingExternalRefresh() -> Bool {
        guard pendingExternalRefresh else { return false }
        pendingExternalRefresh = false
        return true
    }

    // MARK: - Account updates

    func changeScreenName(_ raw: String) async throws {
        let screenName = try AccountProfileValidator.screenName(raw)
        try await performSubmit {
            try await self.service.updateScreenName(screenName)
        }
        switch await refreshAfterMutation() {
        case .refreshed:
            setStatus(NSLocalizedString("昵称已更新", comment: ""), tone: .success)
        case .signedOut:
            setStatus(NSLocalizedString("昵称已更新，请重新登录", comment: ""), tone: .error)
        case .failed:
            setStatus(NSLocalizedString("昵称已更新，但刷新账号资料失败，请稍后点击刷新", comment: ""), tone: .error)
        }
    }

    func changeEmail(old: String, new: String) async throws {
        let values = try AccountProfileValidator.emailChange(old: old, new: new)
        try await performSubmit {
            try await self.service.updateEmail(oldEmail: values.old, newEmail: values.new)
        }
        switch await refreshAfterMutation() {
        case .refreshed:
            setStatus(
                NSLocalizedString("邮箱已更新，可能需要重新验证邮箱或重新登录", comment: ""),
                tone: .success
            )
        case .signedOut:
            setStatus(NSLocalizedString("邮箱已更新，请重新登录", comment: ""), tone: .error)
        case .failed:
            setStatus(NSLocalizedString("邮箱已更新，但刷新账号资料失败，请稍后点击刷新", comment: ""), tone: .error)
        }
    }

    func changePassword(old: String, new: String, confirmation: String) async throws {
        let values = try AccountProfileValidator.passwordChange(
            old: old,
            new: new,
            confirmation: confirmation
        )
        try await performSubmit {
            try await self.service.updatePassword(oldPassword: values.old, newPassword: values.new)
        }
        switch await refreshAfterMutation() {
        case .refreshed:
            setStatus(
                NSLocalizedString("密码已修改；当前会话若已失效，请重新登录", comment: ""),
                tone: .success
            )
        case .signedOut:
            setStatus(NSLocalizedString("密码已修改，请使用新密码重新登录", comment: ""), tone: .error)
        case .failed:
            setStatus(
                NSLocalizedString("密码已修改，但刷新账号资料失败，请稍后重新登录", comment: ""),
                tone: .error
            )
        }
    }

    // MARK: - Email / bangumi

    func verifyEmail() async {
        guard isLoggedIn else {
            setStatus(NSLocalizedString("登录后可管理账号资料", comment: ""), tone: .error)
            return
        }
        guard !isSubmitting else { return }
        isSubmitting = true
        onUpdate?()
        defer {
            isSubmitting = false
            onUpdate?()
        }

        do {
            let token = try await service.fetchWebToken(business: AccountProfileBusiness.emailVerify)
            guard let url = service.makeEmailVerificationURL(webToken: token) else {
                throw AccountProfileServiceError.invalidEndpoint
            }
            openURL(url)
            pendingExternalRefresh = true
            setStatus(
                NSLocalizedString("请在浏览器中完成邮箱验证，返回应用后会自动刷新状态", comment: ""),
                tone: .info
            )
        } catch {
            setStatus(error.localizedDescription, tone: .error)
        }
    }

    func authorizeBangumi() async {
        guard isLoggedIn else {
            setStatus(NSLocalizedString("登录后可管理账号资料", comment: ""), tone: .error)
            return
        }
        guard !isSubmitting else { return }
        isSubmitting = true
        onUpdate?()
        defer {
            isSubmitting = false
            onUpdate?()
        }

        do {
            let url = try await service.fetchBangumiAuthorizationURL()
            openURL(url)
            pendingExternalRefresh = true
            setStatus(
                NSLocalizedString("请在浏览器中完成 bangumi.tv 授权，返回应用后会自动刷新状态", comment: ""),
                tone: .info
            )
        } catch {
            setStatus(error.localizedDescription, tone: .error)
        }
    }

    func manageBangumi() async {
        guard isLoggedIn else {
            setStatus(NSLocalizedString("登录后可管理账号资料", comment: ""), tone: .error)
            return
        }
        guard !isSubmitting else { return }
        isSubmitting = true
        onUpdate?()
        defer {
            isSubmitting = false
            onUpdate?()
        }

        do {
            let token = try await service.fetchWebToken(business: AccountProfileBusiness.oauthBangumi)
            guard let url = service.makeBangumiManagementURL(webToken: token) else {
                throw AccountProfileServiceError.invalidEndpoint
            }
            openURL(url)
            pendingExternalRefresh = true
            setStatus(
                NSLocalizedString("已在浏览器中打开 bangumi.tv 关联管理页面", comment: ""),
                tone: .info
            )
        } catch AccountProfileServiceError.missingWebToken {
            setStatus(
                NSLocalizedString("未找到 bangumi.tv 关联信息，请先完成授权", comment: ""),
                tone: .error
            )
        } catch {
            setStatus(error.localizedDescription, tone: .error)
        }
    }

    // MARK: - Logout

    func logout() async {
        await session.logout()
        isLoggedIn = false
        profile = nil
        pendingExternalRefresh = false
        setStatus(NSLocalizedString("已退出登录", comment: ""), tone: .info)
    }

    // MARK: - Private

    private func performSubmit(_ operation: () async throws -> Void) async throws {
        guard isLoggedIn else {
            throw SessionStore.SessionError.notLoggedIn
        }
        isSubmitting = true
        statusMessage = nil
        onUpdate?()
        defer {
            isSubmitting = false
            onUpdate?()
        }
        try await operation()
    }

    private func refreshAfterMutation() async -> RefreshAfterMutationResult {
        do {
            _ = try await session.validAccessToken()
            try await session.refreshProfile()
            isLoggedIn = await session.isLoggedIn()
            profile = await session.currentProfile()
            return .refreshed
        } catch {
            if isCredentialFailure(error) || isNotLoggedIn(error) {
                await session.logout()
                isLoggedIn = false
                profile = nil
                return .signedOut
            }
            isLoggedIn = await session.isLoggedIn()
            profile = await session.currentProfile()
            return .failed
        }
    }

    private func handleRefreshFailure(_ error: Error, silent: Bool) async {
        if isCredentialFailure(error) || isNotLoggedIn(error) {
            await session.logout()
            isLoggedIn = false
            profile = nil
            if !silent {
                setStatus(NSLocalizedString("登录已过期，请重新登录", comment: ""), tone: .error)
            }
        } else if !silent {
            setStatus(error.localizedDescription, tone: .error)
        }
    }

    private func isCredentialFailure(_ error: Error) -> Bool {
        if let apiError = error as? APIError {
            return apiError.isCredentialFailure
        }
        return false
    }

    private func isNotLoggedIn(_ error: Error) -> Bool {
        guard let sessionError = error as? SessionStore.SessionError else { return false }
        if case .notLoggedIn = sessionError { return true }
        return false
    }

    private func setStatus(_ text: String, tone: AccountProfileStatusTone) {
        statusMessage = AccountProfileStatusMessage(text: text, tone: tone)
        onUpdate?()
    }
}
