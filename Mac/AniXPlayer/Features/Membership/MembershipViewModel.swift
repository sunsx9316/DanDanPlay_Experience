//
//  MembershipViewModel.swift
//  AniXPlayer
//
//  macOS only：会员中心状态与支付编排。
//

import AppKit
import Foundation

struct MembershipPaymentPresentation: Equatable {
    let orderId: String
    let providerId: String
    let title: String
    let amountText: String
    let qrImageData: Data?
    let webURL: URL?
    let expireAt: Date?
    let statusNote: String?

    var providerText: String {
        switch providerId.lowercased() {
        case "wechat":
            return NSLocalizedString("微信扫码支付", comment: "")
        case "alipay":
            return NSLocalizedString("支付宝网页支付", comment: "")
        default:
            return NSLocalizedString("扫码或网页支付", comment: "")
        }
    }
}

enum MembershipPaymentUIState: Equatable {
    case idle
    case creating
    case waiting(MembershipPaymentPresentation, confirming: Bool)
    case success(orderId: String, amountText: String, memberExpireAt: Date?, message: String)
    case expired(orderId: String, message: String)
    case failed(orderId: String?, message: String)
    case cancelled(orderId: String?)
}

@MainActor
final class MembershipViewModel {
    let feature: MembershipFeature?

    private(set) var userInfo: MembershipUserInfo?
    private(set) var payConfigs: [MembershipPayConfig] = []
    private(set) var selectedProviderId: String?
    private(set) var selectedItem: MembershipPayItem?
    private(set) var introMarkdown: String = ""
    private(set) var orderHistory: [MembershipOrderHistoryItem] = []
    private(set) var redeemHistory: [RedeemHistoryItem] = []
    private(set) var paymentState: MembershipPaymentUIState = .idle
    private(set) var isRefreshing = false
    private(set) var isRedeeming = false
    private(set) var isLoadingHistory = false
    private(set) var statusMessage: String?
    private(set) var redeemStatusMessage: String?
    private(set) var redeemSucceeded = false
    private(set) var historyStatusMessage: String?
    /// 本次窗口内是否完成过支付/兑换；用于付费墙返回时区分「取消」。
    private(set) var didCompletePurchase = false

    var onUpdate: (() -> Void)?
    var onMembershipChanged: (() -> Void)?

    private let api: MembershipAPIServing
    private let store: MembershipStore
    private let nowProvider: () -> Date
    private var paymentTask: Task<Void, Never>?
    private var didBegin = false

    private struct CachedOrder {
        let presentation: MembershipPaymentPresentation
        let expiresAt: Date
    }

    private var orderCache: [String: CachedOrder] = [:]

    init(
        feature: MembershipFeature?,
        api: MembershipAPIServing = MembershipAPI(),
        store: MembershipStore? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.feature = feature
        self.api = api
        self.store = store ?? MembershipStore.shared
        self.nowProvider = now
    }

    // MARK: - Lifecycle

    func begin() {
        guard !didBegin else { return }
        didBegin = true

        userInfo = store.cachedUserInfo
        applyPayConfigs()
        onUpdate?()

        Task { @MainActor in
            await refreshMembership(force: true)
            await loadIntro()
            await loadHistory(silent: true)
        }
    }

    func stopAll() {
        paymentTask?.cancel()
        paymentTask = nil
    }

    // MARK: - Derived display state

    var memberExpireDate: Date? {
        store.memberExpireDate
    }

    var memberStatus: EntitlementStatus {
        store.entitlementStatus(for: .member, now: nowProvider())
    }

    var resmonitorStatus: EntitlementStatus {
        store.entitlementStatus(for: .resmonitor, now: nowProvider())
    }

    var hasActiveMembership: Bool {
        memberStatus.isActive
    }

    func isEntitlementActive(_ entitlement: Entitlement) -> Bool {
        store.entitlementStatus(for: entitlement, now: nowProvider()).isActive
    }

    var displayName: String {
        userInfo?.displayName ?? NSLocalizedString("弹弹play用户", comment: "")
    }

    var userNameText: String {
        guard let userName = userInfo?.userName, !userName.isEmpty else { return "" }
        return "@" + userName
    }

    var avatarURLString: String? {
        guard let value = userInfo?.profileImage, !value.isEmpty else { return nil }
        return value
    }

    var memberStatusText: String {
        let status = memberStatus
        if status.isActive, let expiresAt = status.expiresAt {
            return String(
                format: NSLocalizedString("会员生效中，有效期至 %@", comment: ""),
                MembershipDateFormatting.localDateTime(expiresAt)
            )
        }
        if let expiresAt = status.expiresAt {
            return String(
                format: NSLocalizedString("会员已过期（%@）", comment: ""),
                MembershipDateFormatting.localDate(expiresAt)
            )
        }
        return NSLocalizedString("尚未开通会员", comment: "")
    }

    var memberDetailText: String {
        let status = memberStatus
        if status.isActive {
            if status.daysRemaining <= 7 {
                return String(
                    format: NSLocalizedString("会员将于 %d 天后到期，建议及时续费", comment: ""),
                    status.daysRemaining
                )
            }
            return String(
                format: NSLocalizedString("剩余 %d 天，可随时续费叠加时长", comment: ""),
                status.daysRemaining
            )
        }
        return NSLocalizedString("在线支付或使用礼品码兑换会员时长", comment: "")
    }

    var isExpiringSoon: Bool {
        let status = memberStatus
        return status.isActive && status.daysRemaining <= 7
    }

    var featureBannerText: String? {
        guard let feature = feature else { return nil }
        return feature.contextHeadline
    }

    var featureSummaryText: String? {
        guard let feature = feature else { return nil }
        return feature.summary
    }

    var resmonitorText: String? {
        let status = resmonitorStatus
        guard let expiresAt = status.expiresAt else { return nil }
        if status.isActive {
            return String(
                format: NSLocalizedString("资源监视器权益有效期至 %@", comment: ""),
                MembershipDateFormatting.localDateTime(expiresAt)
            )
        }
        return String(
            format: NSLocalizedString("资源监视器权益已过期（%@）", comment: ""),
            MembershipDateFormatting.localDate(expiresAt)
        )
    }

    var payButtonTitle: String {
        hasActiveMembership
            ? NSLocalizedString("续费会员", comment: "")
            : NSLocalizedString("去支付", comment: "")
    }

    var selectedPriceText: String {
        selectedItem?.formattedPrice ?? "—"
    }

    var selectedProvider: MembershipPayConfig? {
        guard let selectedProviderId = selectedProviderId else { return nil }
        return payConfigs.first { $0.providerId == selectedProviderId }
    }

    var currentItems: [MembershipPayItem] {
        selectedProvider?.items ?? []
    }

    var paymentPresentation: MembershipPaymentPresentation? {
        switch paymentState {
        case .waiting(let presentation, _):
            return presentation
        case .success, .expired, .failed:
            return nil
        case .idle, .creating, .cancelled:
            return nil
        }
    }

    var isPaymentInProgress: Bool {
        switch paymentState {
        case .creating, .waiting:
            return true
        default:
            return false
        }
    }

    var canStartPayment: Bool {
        !isRefreshing && !isPaymentInProgress && selectedItem != nil && selectedProviderId != nil
    }

    // MARK: - User info / intro

    func refreshMembership(force: Bool) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        onUpdate?()
        defer {
            isRefreshing = false
            onUpdate?()
        }

        do {
            let info = try await store.refresh(force: force)
            userInfo = info ?? store.cachedUserInfo
            statusMessage = nil
            applyPayConfigs()
        } catch {
            userInfo = store.cachedUserInfo
            statusMessage = error.localizedDescription
            applyPayConfigs()
        }
    }

    func loadIntro() async {
        do {
            let intro = try await api.fetchIntro()
            introMarkdown = intro.markdown.isEmpty ? Self.fallbackIntro : intro.markdown
        } catch {
            introMarkdown = Self.fallbackIntro
        }
        onUpdate?()
    }

    // MARK: - Pay configs

    private func applyPayConfigs() {
        payConfigs = userInfo?.payConfigs ?? store.payConfigs

        if let currentProviderId = selectedProviderId,
           let provider = payConfigs.first(where: { $0.providerId == currentProviderId }) {
            if let currentItem = selectedItem,
               let matching = provider.items.first(where: { $0.id == currentItem.id }) {
                selectedItem = matching
            } else {
                selectedItem = defaultItem(in: provider.items)
            }
            return
        }

        selectedProviderId = payConfigs.first?.providerId
        selectedItem = defaultItem(in: currentItems)
    }

    /// 默认选中间档，避免像 Windows 一样默认落到最贵的 12 个月。
    private func defaultItem(in items: [MembershipPayItem]) -> MembershipPayItem? {
        guard !items.isEmpty else { return nil }
        return items[(items.count - 1) / 2]
    }

    func selectProvider(id: String) {
        guard payConfigs.contains(where: { $0.providerId == id }) else { return }
        selectedProviderId = id
        selectedItem = defaultItem(in: currentItems)
        onUpdate?()
    }

    func selectItem(id: String) {
        guard let item = currentItems.first(where: { $0.id == id }) else { return }
        selectedItem = item
        onUpdate?()
    }

    // MARK: - Payment

    func startPayment() {
        guard !isPaymentInProgress,
              let provider = selectedProvider,
              let item = selectedItem else {
            return
        }

        paymentTask?.cancel()
        let providerId = provider.providerId
        let itemId = item.id
        paymentTask = Task { @MainActor [weak self] in
            await self?.performPayment(provider: provider, item: item, providerId: providerId, itemId: itemId)
        }
    }

    private func performPayment(
        provider: MembershipPayConfig,
        item: MembershipPayItem,
        providerId: String,
        itemId: String
    ) async {
        let cacheKey = providerId + ":" + itemId
        var activeOrderId: String?

        do {
            paymentState = .creating
            onUpdate?()

            if let cached = cachedOrder(for: cacheKey) {
                activeOrderId = cached.presentation.orderId
                paymentState = .waiting(cached.presentation, confirming: false)
                onUpdate?()
                await pollOrder(
                    orderId: cached.presentation.orderId,
                    presentation: cached.presentation,
                    orderExpireAt: cached.expiresAt
                )
                return
            }

            let order = try await api.createOrder(providerId: providerId, itemId: itemId)
            try Task.checkCancellation()
            activeOrderId = order.orderId
            guard !order.orderId.isEmpty else {
                throw MembershipAPIError.invalidResponse(NSLocalizedString("未获取到订单信息，请稍后再试", comment: ""))
            }

            let webURL = order.webURL
            let presentation: MembershipPaymentPresentation

            if provider.isWeChat {
                presentation = try await makeWeChatPresentation(
                    order: order,
                    item: item,
                    webURL: webURL
                )
            } else {
                // 支付宝 Native 二维码需要「当面付」能力，线上未开通，统一走网页支付。
                guard let webURL = webURL else {
                    throw MembershipAPIError.invalidResponse(NSLocalizedString("未获取到支付链接，请稍后再试", comment: ""))
                }
                let opened = openWebURL(webURL)
                presentation = MembershipPaymentPresentation(
                    orderId: order.orderId,
                    providerId: providerId,
                    title: item.name,
                    amountText: item.formattedPrice,
                    qrImageData: nil,
                    webURL: webURL,
                    expireAt: nowProvider().addingTimeInterval(15 * 60),
                    statusNote: opened
                        ? NSLocalizedString("已打开浏览器，请在网页中完成支付", comment: "")
                        : NSLocalizedString("无法打开浏览器，支付链接已复制到剪贴板", comment: "")
                )
            }

            let expiresAt = presentation.expireAt
                ?? nowProvider().addingTimeInterval(15 * 60)
            cacheOrder(
                CachedOrder(presentation: presentation, expiresAt: expiresAt),
                for: cacheKey
            )

            paymentState = .waiting(presentation, confirming: false)
            onUpdate?()
            await pollOrder(
                orderId: order.orderId,
                presentation: presentation,
                orderExpireAt: expiresAt
            )
        } catch {
            if Task.isCancelled || (error as? APIError)?.isCancellation == true {
                paymentState = .cancelled(orderId: activeOrderId)
                onUpdate?()
                return
            }
            paymentState = .failed(
                orderId: activeOrderId,
                message: error.localizedDescription
            )
            onUpdate?()
        }
    }

    private func makeWeChatPresentation(
        order: MembershipOrder,
        item: MembershipPayItem,
        webURL: URL?
    ) async throws -> MembershipPaymentPresentation {
        guard !order.orderToken.isEmpty else {
            throw MembershipAPIError.invalidResponse(NSLocalizedString("未获取到订单凭证，请稍后再试", comment: ""))
        }

        do {
            let qrCode = try await api.fetchQRCode(orderId: order.orderId, orderToken: order.orderToken)
            try Task.checkCancellation()

            guard let imageData = qrCode.qrImageData, NSImage(data: imageData) != nil else {
                throw MembershipAPIError.invalidResponse(NSLocalizedString("未获取到支付二维码", comment: ""))
            }

            let amountText = qrCode.totalAmount.isEmpty
                ? item.formattedPrice
                : qrCode.displayAmount

            return MembershipPaymentPresentation(
                orderId: qrCode.orderId.isEmpty ? order.orderId : qrCode.orderId,
                providerId: qrCode.providerId.isEmpty ? "wechat" : qrCode.providerId,
                title: qrCode.title.isEmpty ? item.name : qrCode.title,
                amountText: amountText,
                qrImageData: imageData,
                webURL: webURL,
                expireAt: qrCode.expireTime,
                statusNote: nil
            )
        } catch {
            if Task.isCancelled || (error as? APIError)?.isCancellation == true {
                throw CancellationError()
            }
            // 二维码失败但订单有网页支付链接：降级到浏览器支付，避免用户卡死。
            if let webURL = webURL {
                let opened = openWebURL(webURL)
                return MembershipPaymentPresentation(
                    orderId: order.orderId,
                    providerId: "wechat",
                    title: item.name,
                    amountText: item.formattedPrice,
                    qrImageData: nil,
                    webURL: webURL,
                    expireAt: nowProvider().addingTimeInterval(15 * 60),
                    statusNote: opened
                        ? NSLocalizedString("二维码生成失败，已改用网页支付", comment: "")
                        : NSLocalizedString("二维码生成失败，支付链接已复制到剪贴板", comment: "")
                )
            }
            throw error
        }
    }

    private func cachedOrder(for key: String) -> CachedOrder? {
        guard let cached = orderCache[key] else { return nil }
        guard cached.expiresAt > nowProvider().addingTimeInterval(30) else {
            orderCache.removeValue(forKey: key)
            return nil
        }
        return cached
    }

    private func cacheOrder(_ order: CachedOrder, for key: String) {
        guard order.expiresAt > nowProvider() else { return }
        orderCache[key] = order
    }

    private func removeCachedOrder(orderId: String) {
        orderCache = orderCache.filter { $0.value.presentation.orderId != orderId }
    }

    private func pollOrder(
        orderId: String,
        presentation: MembershipPaymentPresentation,
        orderExpireAt: Date?
    ) async {
        let deadline = nowProvider().addingTimeInterval(15 * 60)
        var machineState = MembershipPaymentState.waiting(orderId: orderId)
        var consecutiveQueryFailures = 0

        while !Task.isCancelled {
            var status: MembershipOrderStatus?
            var queryFailed = false

            do {
                status = try await api.fetchOrderStatus(orderId: orderId)
            } catch {
                if Task.isCancelled || (error as? APIError)?.isCancellation == true {
                    break
                }
                queryFailed = true
                consecutiveQueryFailures += 1
            }

            if Task.isCancelled { break }

            let nextState = MembershipPaymentStateMachine.next(
                from: machineState,
                status: status,
                queryFailed: queryFailed,
                now: nowProvider(),
                deadline: deadline,
                orderExpireAt: orderExpireAt
            )
            machineState = nextState

            switch nextState {
            case .waiting:
                if !queryFailed {
                    consecutiveQueryFailures = 0
                }
                paymentState = .waiting(
                    presentation,
                    confirming: queryFailed || consecutiveQueryFailures > 0
                )
                onUpdate?()

            case .paid(let paidOrderId, let statusMemberExpireTime):
                removeCachedOrder(orderId: paidOrderId)
                let refreshedInfo: MembershipUserInfo?
                do {
                    refreshedInfo = try await store.refresh(force: true)
                } catch {
                    refreshedInfo = store.cachedUserInfo
                }
                userInfo = refreshedInfo ?? userInfo
                applyPayConfigs()

                let expireDate = refreshedInfo?.privileges.member
                    ?? statusMemberExpireTime
                    ?? store.memberExpireDate
                let message: String
                if let expireDate = expireDate {
                    message = String(
                        format: NSLocalizedString("支付成功，会员有效期至 %@", comment: ""),
                        MembershipDateFormatting.localDateTime(expireDate)
                    )
                } else {
                    message = NSLocalizedString("支付成功，会员权益已更新", comment: "")
                }

                didCompletePurchase = true
                paymentState = .success(
                    orderId: paidOrderId,
                    amountText: presentation.amountText,
                    memberExpireAt: expireDate,
                    message: message
                )
                onMembershipChanged?()
                onUpdate?()
                return

            case .timedOut(let timedOutOrderId, let reason):
                removeCachedOrder(orderId: timedOutOrderId)
                paymentState = .expired(
                    orderId: timedOutOrderId,
                    message: timeoutMessage(reason: reason, orderId: timedOutOrderId)
                )
                onUpdate?()
                return

            }

            let delay: TimeInterval
            if queryFailed {
                delay = consecutiveQueryFailures <= 1 ? 5 : 10
            } else {
                delay = 2
            }

            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch {
                break
            }
        }

        if Task.isCancelled {
            paymentState = .cancelled(orderId: orderId)
            onUpdate?()
        }
    }

    private func timeoutMessage(reason: MembershipPaymentTimeoutReason, orderId: String) -> String {
        switch reason {
        case .orderExpired:
            return String(
                format: NSLocalizedString("支付订单已过期。如已付款，请勿重复支付，请稍后在购买记录中确认；如未付款，请重新下单。\n订单号：%@", comment: ""),
                orderId
            )
        case .pollLimitReached:
            return String(
                format: NSLocalizedString("等待支付超时（15 分钟）。如已付款，请勿重复支付，请稍后在购买记录中确认。\n订单号：%@", comment: ""),
                orderId
            )
        }
    }

    func cancelPayment() {
        paymentTask?.cancel()
        paymentTask = nil

        let orderId: String?
        switch paymentState {
        case .waiting(let presentation, _):
            orderId = presentation.orderId
        case .creating:
            orderId = nil
        default:
            orderId = nil
        }
        paymentState = .cancelled(orderId: orderId)
        onUpdate?()
    }

    func resetPayment() {
        paymentTask?.cancel()
        paymentTask = nil
        paymentState = .idle
        onUpdate?()
    }

    func openWebPayment() {
        guard let presentation = paymentPresentation, let url = presentation.webURL else { return }
        let opened = openWebURL(url)
        if !opened {
            statusMessage = NSLocalizedString("无法打开浏览器，支付链接已复制到剪贴板", comment: "")
            onUpdate?()
        }
    }

    @discardableResult
    private func openWebURL(_ url: URL) -> Bool {
        if NSWorkspace.shared.open(url) {
            return true
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url.absoluteString, forType: .string)
        return false
    }

    // MARK: - Redeem

    func redeem(code rawCode: String) async {
        let code = Self.sanitizedPromoCode(rawCode)
        guard !code.isEmpty else {
            redeemSucceeded = false
            redeemStatusMessage = NSLocalizedString("请输入礼品码", comment: "")
            onUpdate?()
            return
        }
        guard code.count <= 20 else {
            redeemSucceeded = false
            redeemStatusMessage = NSLocalizedString("礼品码长度不能超过 20 个字符", comment: "")
            onUpdate?()
            return
        }
        guard !isRedeeming else { return }

        isRedeeming = true
        redeemStatusMessage = NSLocalizedString("正在兑换礼品码…", comment: "")
        redeemSucceeded = false
        onUpdate?()

        defer {
            isRedeeming = false
            onUpdate?()
        }

        do {
            let result = try await api.redeem(code: code)
            let refreshedInfo: MembershipUserInfo?
            do {
                refreshedInfo = try await store.refresh(force: true)
            } catch {
                refreshedInfo = store.cachedUserInfo
            }
            userInfo = refreshedInfo ?? userInfo
            applyPayConfigs()

            let expireDate = refreshedInfo?.privileges.member
                ?? result.memberExpireDate
            if let expireDate = expireDate {
                redeemStatusMessage = String(
                    format: NSLocalizedString("礼品码兑换成功，会员有效期至 %@", comment: ""),
                    MembershipDateFormatting.localDateTime(expireDate)
                )
            } else {
                redeemStatusMessage = NSLocalizedString("礼品码兑换成功，会员权益已更新", comment: "")
            }
            redeemSucceeded = true
            didCompletePurchase = true
            onMembershipChanged?()
            await loadHistory(silent: true)
        } catch {
            redeemSucceeded = false
            redeemStatusMessage = error.localizedDescription
        }
    }

    /// 去空格/连字符，长度限制在 20（与 Windows 的礼品码规则一致）。
    static func sanitizedPromoCode(_ raw: String) -> String {
        MembershipPromoCode.sanitized(raw)
    }

    // MARK: - History

    func loadHistory(silent: Bool = false) async {
        guard !isLoadingHistory else { return }
        isLoadingHistory = true
        if !silent { onUpdate?() }
        defer {
            isLoadingHistory = false
            onUpdate?()
        }

        var errors: [String] = []
        do {
            orderHistory = try await api.fetchOrderHistory()
                .sorted { ($0.orderTime ?? .distantPast) > ($1.orderTime ?? .distantPast) }
        } catch {
            errors.append(String(format: NSLocalizedString("购买记录加载失败：%@", comment: ""), error.localizedDescription))
        }

        do {
            redeemHistory = try await api.fetchRedeemHistory()
                .sorted { ($0.redeemTime ?? .distantPast) > ($1.redeemTime ?? .distantPast) }
        } catch {
            errors.append(String(format: NSLocalizedString("兑换记录加载失败：%@", comment: ""), error.localizedDescription))
        }

        historyStatusMessage = errors.isEmpty ? nil : errors.joined(separator: "\n")
    }

    // MARK: - Fallback intro

    private static let fallbackIntro: String = {
        var lines: [String] = []
        lines.append(NSLocalizedString("# 弹弹play会员", comment: ""))
        lines.append(NSLocalizedString("会员时长按到期时间叠加，购买或兑换后立即生效。", comment: ""))
        lines.append("")
        for feature in MembershipFeature.allCases where feature.entitlement == .member {
            lines.append("- **\(feature.title)**：\(feature.summary)")
        }
        lines.append("")
        lines.append(NSLocalizedString("基础播放、SMB/WebDAV/FTP、Emby/Jellyfin 与弹幕匹配保持免费。", comment: ""))
        return lines.joined(separator: "\n")
    }()
}

private extension APIError {
    var isCancellation: Bool {
        if case .cancelled = self {
            return true
        }
        return false
    }
}
