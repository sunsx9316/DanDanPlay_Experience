//
//  MembershipStore.swift
//  AniXPlayer
//
//  macOS only：会员权益缓存。
//
//  原则：
//  - 永远以服务端 `/user/me` 为准，不在本地加会员时间；
//  - 缓存 60 秒，支付/兑换成功、登录、登出时强制刷新；
//  - 权益变化通过 Notification.Name.membershipDidChange 广播。
//

import Foundation

extension Notification.Name {
    /// 会员权益或商品配置发生变化（登录、登出、支付成功、兑换成功、主动刷新）。
    static let membershipDidChange = Notification.Name("membershipDidChange")
}

@MainActor
protocol MembershipEntitlementProviding: AnyObject {
    var cachedUserInfo: MembershipUserInfo? { get }

    @discardableResult
    func refresh(force: Bool) async throws -> MembershipUserInfo?

    func entitlementStatus(for entitlement: Entitlement, now: Date) -> EntitlementStatus
}

@MainActor
final class MembershipStore: NSObject, MembershipEntitlementProviding {
    static let shared = MembershipStore()

    private(set) var cachedUserInfo: MembershipUserInfo?
    private(set) var lastRefreshDate: Date?

    /// 最近一次成功获取 `/user/me` 后经过的时间。
    var cacheAge: TimeInterval? {
        guard let lastRefreshDate = lastRefreshDate else { return nil }
        return nowProvider().timeIntervalSince(lastRefreshDate)
    }

    var userInfo: MembershipUserInfo? { cachedUserInfo }

    var payConfigs: [MembershipPayConfig] {
        cachedUserInfo?.payConfigs ?? []
    }

    var memberExpireDate: Date? {
        cachedUserInfo?.privileges.member
    }

    var resmonitorExpireDate: Date? {
        cachedUserInfo?.privileges.resmonitor
    }

    var isMember: Bool {
        guard let member = memberExpireDate else { return false }
        return member > nowProvider()
    }

    func entitlementStatus(for entitlement: Entitlement, now: Date) -> EntitlementStatus {
        return cachedUserInfo?.status(for: entitlement, at: now)
            ?? EntitlementStatus(entitlement: entitlement, expiresAt: nil, now: now)
    }

    private let api: MembershipAPIServing
    private let isLoggedInProvider: () async -> Bool
    private let nowProvider: () -> Date
    private let cacheTTL: TimeInterval
    private var refreshTask: Task<MembershipUserInfo?, Error>?

    init(
        api: MembershipAPIServing = MembershipAPI(),
        isLoggedIn: (() async -> Bool)? = nil,
        now: @escaping () -> Date = Date.init,
        cacheTTL: TimeInterval = 60
    ) {
        self.api = api
        // `.refreshing` / `.restoring` 仍可能持有 refresh token，不应清除权益缓存。
        self.isLoggedInProvider = isLoggedIn ?? {
            await SessionStore.shared.currentState() != .loggedOut
        }
        self.nowProvider = now
        self.cacheTTL = cacheTTL
        super.init()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(loginStateDidChange),
            name: .AnixUserLoginStateDidChange,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Refresh

    /// 刷新权益。未登录时清空缓存并返回 nil。
    ///
    /// - Parameter force: true 时跳过 60 秒 TTL（支付/兑换/登录后的强制刷新）。
    @discardableResult
    func refresh(force: Bool = false) async throws -> MembershipUserInfo? {
        guard await isLoggedInProvider() else {
            clearCache(postNotification: cachedUserInfo != nil)
            return nil
        }

        if !force,
           let cachedUserInfo = cachedUserInfo,
           let cacheAge = cacheAge,
           cacheAge >= 0,
           cacheAge < cacheTTL {
            return cachedUserInfo
        }

        // 并发刷新单飞：门禁、会员中心、设置页同时请求时只打一次接口。
        if let refreshTask = refreshTask {
            return try await refreshTask.value
        }

        let task = Task { @MainActor [api] () throws -> MembershipUserInfo? in
            let info = try await api.fetchUserInfo()
            self.apply(info, forceNotify: force)
            return info
        }
        refreshTask = task

        defer { refreshTask = nil }
        return try await task.value
    }

    /// 无论缓存是否过期都重新拉一次，用于支付/兑换成功后的确认。
    @discardableResult
    func forceRefresh() async throws -> MembershipUserInfo? {
        try await refresh(force: true)
    }

    func clearCache(postNotification: Bool = true) {
        let hadCache = cachedUserInfo != nil
        cachedUserInfo = nil
        lastRefreshDate = nil
        refreshTask?.cancel()
        refreshTask = nil
        if postNotification && hadCache {
            notifyChanged()
        }
    }

    private func apply(_ info: MembershipUserInfo, forceNotify: Bool) {
        let changed = cachedUserInfo != info
        cachedUserInfo = info
        lastRefreshDate = nowProvider()
        if changed || forceNotify {
            notifyChanged()
        }
    }

    private func notifyChanged() {
        NotificationCenter.default.post(name: .membershipDidChange, object: self)
    }

    // MARK: - Login state

    @objc private func loginStateDidChange() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            // 注意：token 刷新期间 SessionStore 状态是 .refreshing，
            // 不能把它当成登出，否则会取消正在进行的 /user/me 请求。
            let state = await SessionStore.shared.currentState()
            switch state {
            case .loggedIn:
                do {
                    _ = try await self.refresh(force: true)
                } catch {
                    // 网络错误时保留缓存；真正的凭证失效由 SessionStore 处理。
                }
            case .loggedOut:
                self.clearCache(postNotification: true)
            case .restoring, .refreshing:
                break
            }
        }
    }
}
