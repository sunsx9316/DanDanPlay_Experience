//
//  MembershipModels.swift
//  AniXPlayer
//
//  macOS only：会员、商品、订单、兑换相关模型。
//
//  约定：
//  - 服务端时间均为北京时间（UTC+8），解析后统一保存为绝对时间 Date；
//  - 金额一律使用「分」为单位的整数或 Decimal 计算，展示时再格式化；
//  - 所有 `success=false` 的 200 响应由 MembershipAPI 转成 MembershipAPIError。
//

import Foundation

// MARK: - 错误

enum MembershipAPIError: LocalizedError {
    /// 服务端以 200 返回 `success=false`，带业务错误文案。
    case server(message: String, code: Int?)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .server(let message, _):
            return message.isEmpty ? NSLocalizedString("操作失败，请稍后重试", comment: "") : message
        case .invalidResponse(let message):
            return message
        }
    }
}

// MARK: - 权益

/// 用户权益到期时间（服务端按北京时间下发）。
struct MembershipPrivilege: Decodable, Equatable, Sendable {
    let member: Date?
    let resmonitor: Date?

    enum CodingKeys: String, CodingKey {
        case member
        case resmonitor
    }

    init(member: Date? = nil, resmonitor: Date? = nil) {
        self.member = member
        self.resmonitor = resmonitor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.member = Self.decodeDate(container, key: .member)
        self.resmonitor = Self.decodeDate(container, key: .resmonitor)
    }

    private static func decodeDate(
        _ container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> Date? {
        guard let string = container.decodeFlexibleString(forKey: key) else { return nil }
        return DDPDateParser.parse(string)
    }

    func expirationDate(for entitlement: Entitlement) -> Date? {
        switch entitlement {
        case .member:
            return member
        case .resmonitor:
            return resmonitor
        }
    }
}

enum Entitlement: String, CaseIterable, Sendable {
    case member
    case resmonitor

    var displayName: String {
        switch self {
        case .member:
            return NSLocalizedString("弹弹play会员", comment: "")
        case .resmonitor:
            return NSLocalizedString("资源监视器", comment: "")
        }
    }
}

struct EntitlementStatus: Equatable, Sendable {
    let entitlement: Entitlement
    let expiresAt: Date?
    let now: Date

    /// 是否在有效期内。判断始终用服务端时间换算出的绝对时间，不在本地延长会员。
    var isActive: Bool {
        guard let expiresAt = expiresAt else { return false }
        return expiresAt > now
    }

    /// 剩余天数（不足一天按一天计；已过期返回 0）。
    var daysRemaining: Int {
        guard let expiresAt = expiresAt, expiresAt > now else { return 0 }
        let seconds = expiresAt.timeIntervalSince(now)
        return max(1, Int(ceil(seconds / 86_400)))
    }
}

// MARK: - 商品

struct MembershipPayItem: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    /// 单位：分。
    let price: Int
    let currency: String

    init(id: String, name: String, price: Int, currency: String = "CNY") {
        self.id = id
        self.name = name
        self.price = price
        self.currency = currency
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case price
        case currency
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = container.decodeFlexibleString(forKey: .id) ?? ""
        self.name = container.decodeFlexibleString(forKey: .name) ?? ""
        if let intValue = try? container.decodeIfPresent(Int.self, forKey: .price) {
            self.price = intValue
        } else if let stringValue = container.decodeFlexibleString(forKey: .price),
                  let decimal = Decimal(string: stringValue, locale: Locale(identifier: "en_US_POSIX")) {
            self.price = NSDecimalNumber(decimal: decimal).intValue
        } else {
            self.price = 0
        }
        let currency = container.decodeFlexibleString(forKey: .currency) ?? ""
        self.currency = currency.isEmpty ? "CNY" : currency
    }

    var formattedPrice: String {
        MembershipMoney.format(cents: price, currency: currency)
    }
}

struct MembershipPayConfig: Decodable, Equatable, Identifiable, Sendable {
    let providerId: String
    let providerName: String
    let items: [MembershipPayItem]

    var id: String { providerId }

    init(providerId: String, providerName: String, items: [MembershipPayItem]) {
        self.providerId = providerId
        self.providerName = providerName
        self.items = items
    }

    enum CodingKeys: String, CodingKey {
        case providerId
        case providerName
        case items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.providerId = container.decodeFlexibleString(forKey: .providerId) ?? ""
        self.providerName = container.decodeFlexibleString(forKey: .providerName) ?? ""
        self.items = (try? container.decodeIfPresent([MembershipPayItem].self, forKey: .items)) ?? []
    }

    var isWeChat: Bool {
        providerId.lowercased() == "wechat"
    }

    var isAlipay: Bool {
        providerId.lowercased() == "alipay"
    }
}

// MARK: - 用户

/// `/user/me` 中会员需要的字段。
struct MembershipUserInfo: Decodable, Equatable, Sendable {
    let userId: Int
    let userName: String
    let screenName: String
    let profileImage: String
    let privileges: MembershipPrivilege
    let payConfigs: [MembershipPayConfig]

    init(
        userId: Int = 0,
        userName: String = "",
        screenName: String = "",
        profileImage: String = "",
        privileges: MembershipPrivilege = MembershipPrivilege(),
        payConfigs: [MembershipPayConfig] = []
    ) {
        self.userId = userId
        self.userName = userName
        self.screenName = screenName
        self.profileImage = profileImage
        self.privileges = privileges
        self.payConfigs = payConfigs
    }

    enum CodingKeys: String, CodingKey {
        case userId
        case userName
        case screenName
        case profileImage
        case privileges
        case payConfigs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let intValue = try? container.decodeIfPresent(Int.self, forKey: .userId) {
            self.userId = intValue
        } else if let stringValue = container.decodeFlexibleString(forKey: .userId) {
            self.userId = Int(stringValue) ?? 0
        } else {
            self.userId = 0
        }
        self.userName = container.decodeFlexibleString(forKey: .userName) ?? ""
        self.screenName = container.decodeFlexibleString(forKey: .screenName) ?? ""
        self.profileImage = container.decodeFlexibleString(forKey: .profileImage) ?? ""
        self.privileges = (try? container.decodeIfPresent(MembershipPrivilege.self, forKey: .privileges))
            ?? MembershipPrivilege()
        self.payConfigs = (try? container.decodeIfPresent([MembershipPayConfig].self, forKey: .payConfigs))
            ?? []
    }

    var displayName: String {
        if !screenName.isEmpty { return screenName }
        if !userName.isEmpty { return userName }
        return userId > 0 ? String(format: NSLocalizedString("用户 %d", comment: ""), userId) : NSLocalizedString("弹弹play用户", comment: "")
    }

    func isMember(at date: Date = Date()) -> Bool {
        guard let member = privileges.member else { return false }
        return member > date
    }

    func status(for entitlement: Entitlement, at date: Date = Date()) -> EntitlementStatus {
        EntitlementStatus(
            entitlement: entitlement,
            expiresAt: privileges.expirationDate(for: entitlement),
            now: date
        )
    }
}

// MARK: - 订单

struct MembershipOrder: Decodable, Equatable, Sendable {
    let orderId: String
    let orderToken: String
    let url: String

    init(orderId: String, orderToken: String = "", url: String = "") {
        self.orderId = orderId
        self.orderToken = orderToken
        self.url = url
    }

    enum CodingKeys: String, CodingKey {
        case orderId
        case orderToken
        case url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.orderId = container.decodeFlexibleString(forKey: .orderId) ?? ""
        self.orderToken = container.decodeFlexibleString(forKey: .orderToken) ?? ""
        self.url = container.decodeFlexibleString(forKey: .url) ?? ""
    }

    var webURL: URL? {
        guard !url.isEmpty, let url = URL(string: url) else { return nil }
        return url
    }
}

struct MembershipQRCode: Decodable, Equatable, Sendable {
    let orderId: String
    let providerId: String
    let title: String
    let totalAmount: String
    let currency: String
    let expireTime: Date?
    let qrCodeBase64: String

    init(
        orderId: String,
        providerId: String,
        title: String,
        totalAmount: String,
        currency: String,
        expireTime: Date?,
        qrCodeBase64: String
    ) {
        self.orderId = orderId
        self.providerId = providerId
        self.title = title
        self.totalAmount = totalAmount
        self.currency = currency
        self.expireTime = expireTime
        self.qrCodeBase64 = qrCodeBase64
    }

    enum CodingKeys: String, CodingKey {
        case orderId
        case providerId
        case title
        case totalAmount
        case currency
        case expireTime
        case qrCodeBase64
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.orderId = container.decodeFlexibleString(forKey: .orderId) ?? ""
        self.providerId = container.decodeFlexibleString(forKey: .providerId) ?? ""
        self.title = container.decodeFlexibleString(forKey: .title) ?? ""
        self.totalAmount = container.decodeFlexibleString(forKey: .totalAmount) ?? ""
        self.currency = container.decodeFlexibleString(forKey: .currency) ?? "CNY"
        if let dateString = container.decodeFlexibleString(forKey: .expireTime) {
            self.expireTime = DDPDateParser.parse(dateString)
        } else {
            self.expireTime = nil
        }
        self.qrCodeBase64 = container.decodeFlexibleString(forKey: .qrCodeBase64) ?? ""
    }

    var displayAmount: String {
        MembershipMoney.format(totalAmount: totalAmount, currency: currency)
    }

    /// 服务端可能返回 `data:image/png;base64,` 前缀，统一剥掉。
    var qrImageData: Data? {
        var payload = qrCodeBase64.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = payload.range(of: "base64,", options: .caseInsensitive) {
            payload = String(payload[range.upperBound...])
        }
        payload = payload.replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
        guard !payload.isEmpty else { return nil }
        return Data(base64Encoded: payload, options: .ignoreUnknownCharacters)
    }
}

struct MembershipOrderStatus: Decodable, Equatable, Sendable {
    let orderId: String
    let isPaid: Bool
    let memberExpireTime: Date?

    init(orderId: String, isPaid: Bool, memberExpireTime: Date? = nil) {
        self.orderId = orderId
        self.isPaid = isPaid
        self.memberExpireTime = memberExpireTime
    }

    enum CodingKeys: String, CodingKey {
        case orderId
        case isPaid
        case memberExpireTime
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.orderId = container.decodeFlexibleString(forKey: .orderId) ?? ""
        self.isPaid = (try? container.decodeIfPresent(Bool.self, forKey: .isPaid)) ?? false
        if let dateString = container.decodeFlexibleString(forKey: .memberExpireTime) {
            self.memberExpireTime = DDPDateParser.parse(dateString)
        } else {
            self.memberExpireTime = nil
        }
    }
}

struct MembershipOrderHistoryItem: Decodable, Equatable, Sendable {
    let orderId: String
    let orderTime: Date?
    let addDays: Int
    let toTime: Date?
    let title: String
    let description: String
    let totalAmount: String
    let currency: String

    init(
        orderId: String,
        orderTime: Date?,
        addDays: Int,
        toTime: Date?,
        title: String,
        description: String,
        totalAmount: String,
        currency: String
    ) {
        self.orderId = orderId
        self.orderTime = orderTime
        self.addDays = addDays
        self.toTime = toTime
        self.title = title
        self.description = description
        self.totalAmount = totalAmount
        self.currency = currency
    }

    enum CodingKeys: String, CodingKey {
        case orderId
        case orderTime
        case addDays
        case toTime
        case title
        case description
        case totalAmount
        case currency
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.orderId = container.decodeFlexibleString(forKey: .orderId) ?? ""
        self.orderTime = container.decodeFlexibleDate(forKey: .orderTime)
        self.addDays = (try? container.decodeIfPresent(Int.self, forKey: .addDays)) ?? 0
        self.toTime = container.decodeFlexibleDate(forKey: .toTime)
        self.title = container.decodeFlexibleString(forKey: .title) ?? ""
        self.description = container.decodeFlexibleString(forKey: .description) ?? ""
        self.totalAmount = container.decodeFlexibleString(forKey: .totalAmount) ?? ""
        self.currency = container.decodeFlexibleString(forKey: .currency) ?? "CNY"
    }

    var displayAmount: String {
        MembershipMoney.format(totalAmount: totalAmount, currency: currency)
    }
}

struct MembershipOrderHistoryResponse: Decodable, Equatable, Sendable {
    let orderList: [MembershipOrderHistoryItem]

    init(orderList: [MembershipOrderHistoryItem] = []) {
        self.orderList = orderList
    }

    enum CodingKeys: String, CodingKey {
        case orderList
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.orderList = (try? container.decodeIfPresent([MembershipOrderHistoryItem].self, forKey: .orderList)) ?? []
    }
}

// MARK: - 礼品码

struct RedeemResult: Decodable, Equatable, Sendable {
    let privilege: MembershipPrivilege
    let addDays: Int?
    let toTime: Date?

    init(privilege: MembershipPrivilege = MembershipPrivilege(), addDays: Int? = nil, toTime: Date? = nil) {
        self.privilege = privilege
        self.addDays = addDays
        self.toTime = toTime
    }

    enum CodingKeys: String, CodingKey {
        case privilege
        case addDays
        case toTime
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.privilege = (try? container.decodeIfPresent(MembershipPrivilege.self, forKey: .privilege))
            ?? MembershipPrivilege()
        self.addDays = try? container.decodeIfPresent(Int.self, forKey: .addDays)
        self.toTime = container.decodeFlexibleDate(forKey: .toTime)
    }

    var memberExpireDate: Date? {
        privilege.member ?? toTime
    }
}

struct RedeemHistoryItem: Decodable, Equatable, Sendable {
    let redeemTime: Date?
    let promoCode: String
    let addDays: Int
    let toTime: Date?
    let description: String

    init(redeemTime: Date?, promoCode: String, addDays: Int, toTime: Date?, description: String) {
        self.redeemTime = redeemTime
        self.promoCode = promoCode
        self.addDays = addDays
        self.toTime = toTime
        self.description = description
    }

    enum CodingKeys: String, CodingKey {
        case redeemTime
        case promoCode
        case addDays
        case toTime
        case description
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.redeemTime = container.decodeFlexibleDate(forKey: .redeemTime)
        self.promoCode = container.decodeFlexibleString(forKey: .promoCode) ?? ""
        self.addDays = (try? container.decodeIfPresent(Int.self, forKey: .addDays)) ?? 0
        self.toTime = container.decodeFlexibleDate(forKey: .toTime)
        self.description = container.decodeFlexibleString(forKey: .description) ?? ""
    }
}

struct MembershipRedeemHistoryResponse: Decodable, Equatable, Sendable {
    let redeemList: [RedeemHistoryItem]

    init(redeemList: [RedeemHistoryItem] = []) {
        self.redeemList = redeemList
    }

    enum CodingKeys: String, CodingKey {
        case redeemList
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.redeemList = (try? container.decodeIfPresent([RedeemHistoryItem].self, forKey: .redeemList)) ?? []
    }
}

// MARK: - 会员介绍

struct MembershipIntro: Decodable, Equatable, Sendable {
    let markdown: String

    init(markdown: String) {
        self.markdown = markdown
    }

    enum CodingKeys: String, CodingKey {
        case markdown
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.markdown = container.decodeFlexibleString(forKey: .markdown) ?? ""
    }
}

// MARK: - 响应状态信封
//
// 服务端业务响应将 `success`/`errorMessage`/`errorCode` 放在顶层，
// 与业务字段平铺。这里先单独解码状态，再由 MembershipAPI 解码业务体。

struct MembershipResponseStatus: Decodable, Sendable {
    let success: Bool?
    let errorMessage: String?
    let errorCode: Int?
    let errorDetail: String?

    enum CodingKeys: String, CodingKey {
        case success
        case errorMessage
        case errorCode
        case errorDetail
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.success = try? container.decodeIfPresent(Bool.self, forKey: .success)
        self.errorMessage = container.decodeFlexibleString(forKey: .errorMessage)
        self.errorDetail = container.decodeFlexibleString(forKey: .errorDetail)
        if let intValue = try? container.decodeIfPresent(Int.self, forKey: .errorCode) {
            self.errorCode = intValue
        } else if let stringValue = container.decodeFlexibleString(forKey: .errorCode) {
            self.errorCode = Int(stringValue)
        } else {
            self.errorCode = nil
        }
    }

    var isFailure: Bool {
        success == false
    }

    var displayMessage: String? {
        for candidate in [errorMessage, errorDetail] {
            if let candidate = candidate?.trimmingCharacters(in: .whitespacesAndNewlines),
               !candidate.isEmpty {
                return candidate
            }
        }
        return nil
    }
}

// MARK: - 礼品码

enum MembershipPromoCode {
    static let maxLength = 20

    /// 去空格/连字符并限制长度；不做大小写转换，以服务端规则为准。
    static func sanitized(_ raw: String) -> String {
        let removedWhitespace = raw.components(separatedBy: .whitespacesAndNewlines).joined()
        let removedHyphens = removedWhitespace.replacingOccurrences(of: "-", with: "")
        return String(removedHyphens.prefix(maxLength))
    }
}

// MARK: - 金额

enum MembershipMoney {
    /// 分 -> `¥15.00`。货币符号与金额之间不加空格，符合中文界面习惯。
    static func format(cents: Int, currency: String) -> String {
        let amount = Decimal(cents) / 100
        return format(decimal: amount, currency: currency)
    }

    /// 服务端返回的字符串金额（如 "15.00"）-> 展示文案。
    static func format(totalAmount: String, currency: String) -> String {
        let trimmed = totalAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return symbol(for: currency)
        }
        // 去掉可能出现的货币符号，只保留数字部分。
        let filtered = trimmed.filter { $0.isNumber || $0 == "." || $0 == "-" }
        guard let amount = Decimal(string: filtered, locale: Locale(identifier: "en_US_POSIX")) else {
            return symbol(for: currency) + trimmed
        }
        return format(decimal: amount, currency: currency)
    }

    static func format(decimal: Decimal, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.roundingMode = .halfUp

        let number = NSDecimalNumber(decimal: decimal)
        let text = formatter.string(from: number) ?? number.stringValue
        return symbol(for: currency) + text
    }

    static func symbol(for currency: String) -> String {
        switch currency.uppercased() {
        case "CNY", "RMB":
            return "¥"
        case "USD":
            return "$"
        case "JPY":
            return "¥"
        case "EUR":
            return "€"
        case "KRW":
            return "₩"
        case "HKD":
            return "HK$"
        case "":
            return "¥"
        default:
            return currency.uppercased() + " "
        }
    }
}

// MARK: - 日期展示

enum MembershipDateFormatting {
    static func localDateTime(_ date: Date?) -> String {
        guard let date = date else { return "—" }
        return localDateTimeFormatter.string(from: date)
    }

    static func localDate(_ date: Date?) -> String {
        guard let date = date else { return "—" }
        return localDateFormatter.string(from: date)
    }

    static func countdown(seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let minutes = total / 60
        let remainingSeconds = total % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    private static let localDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private static let localDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

// MARK: - 支付状态机（纯逻辑，便于单测）

enum MembershipPaymentTimeoutReason: Equatable, Sendable {
    case orderExpired
    case pollLimitReached
}

enum MembershipPaymentState: Equatable, Sendable {
    case waiting(orderId: String)
    case paid(orderId: String, memberExpireAt: Date?)
    case timedOut(orderId: String, reason: MembershipPaymentTimeoutReason)
}

enum MembershipPaymentStateMachine {
    /// 根据一次订单状态查询结果推进状态。
    ///
    /// - 支付成功优先于超时：即使刚好到截止时间，只要服务端已确认付款就判定成功；
    /// - 查询失败只表示「确认中」，不改变 waiting 状态；
    /// - 订单过期与总轮询超时分别给出不同原因，便于 UI 文案区分。
    static func next(
        from state: MembershipPaymentState,
        status: MembershipOrderStatus?,
        queryFailed: Bool,
        now: Date,
        deadline: Date,
        orderExpireAt: Date?
    ) -> MembershipPaymentState {
        if case .paid = state {
            return state
        }

        let orderId: String
        switch state {
        case .waiting(let currentOrderId):
            orderId = currentOrderId
        case .paid(let currentOrderId, _):
            orderId = currentOrderId
        case .timedOut(let currentOrderId, _):
            orderId = currentOrderId
        }

        if let status = status, status.isPaid {
            let resolvedOrderId = status.orderId.isEmpty ? orderId : status.orderId
            return .paid(orderId: resolvedOrderId, memberExpireAt: status.memberExpireTime)
        }

        if let orderExpireAt = orderExpireAt, now >= orderExpireAt {
            return .timedOut(orderId: orderId, reason: .orderExpired)
        }

        if now >= deadline {
            return .timedOut(orderId: orderId, reason: .pollLimitReached)
        }

        _ = queryFailed // 查询失败继续等待，由调用方负责退避与「确认中」文案。
        return .waiting(orderId: orderId)
    }
}

// MARK: - 解码辅助

extension KeyedDecodingContainer {
    /// 兼容 String / 数字 / 布尔等标量，统一转成字符串。
    func decodeFlexibleString(forKey key: Key) -> String? {
        if let string = try? decodeIfPresent(String.self, forKey: key) {
            return string
        }
        if let int = try? decodeIfPresent(Int.self, forKey: key) {
            return String(int)
        }
        if let int64 = try? decodeIfPresent(Int64.self, forKey: key) {
            return String(int64)
        }
        if let double = try? decodeIfPresent(Double.self, forKey: key) {
            return String(double)
        }
        if let bool = try? decodeIfPresent(Bool.self, forKey: key) {
            return bool ? "true" : "false"
        }
        return nil
    }

    /// 兼容带时区/不带时区/带毫秒的日期字符串。
    func decodeFlexibleDate(forKey key: Key) -> Date? {
        guard let string = decodeFlexibleString(forKey: key), !string.isEmpty else {
            return nil
        }
        return DDPDateParser.parse(string)
    }
}
