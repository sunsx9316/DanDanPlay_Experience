//
//  MembershipTests.swift
//  AniXPlayerTests
//
//  无宿主单元测试：会员模型、金额、支付状态机、权益门禁、缓存与历史记录解码。
//  真实支付无法自动验证；API 层用 StubURLProtocol 模拟服务端响应。
//

import Foundation
import XCTest

// MARK: - 测试辅助

private func membershipDate(_ string: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    guard let date = formatter.date(from: string) else {
        fatalError("invalid date: \(string)")
    }
    return date
}

private let fixedNow = membershipDate("2026-11-16T12:00:00+08:00")
private let oneDay: TimeInterval = 86_400

private func makeUserInfoJSON(member: String, resmonitor: String? = nil) -> Data {
    let resmonitorValue = resmonitor.map { "\"\($0)\"" } ?? "null"
    let json = """
    {
      "userId": 123,
      "userName": "kaede",
      "screenName": "Kaede",
      "email": "a@b.com",
      "emailVerified": true,
      "profileImage": "https://example.com/avatar.png",
      "privileges": {
        "member": "\(member)",
        "resmonitor": \(resmonitorValue)
      },
      "payConfigs": [
        {
          "providerId": "wechat",
          "providerName": "微信支付",
          "items": [
            { "id": "wechat1m", "name": "1个月会员", "price": 1500, "currency": "CNY" },
            { "id": "wechat3m", "name": "3个月会员", "price": 4000, "currency": "CNY" },
            { "id": "wechat6m", "name": "6个月会员", "price": 7000, "currency": "CNY" },
            { "id": "wechat12m", "name": "12个月会员", "price": 12000, "currency": "CNY" }
          ]
        },
        {
          "providerId": "alipay",
          "providerName": "支付宝",
          "items": [
            { "id": "alipay1m", "name": "1个月会员", "price": 1500, "currency": "CNY" }
          ]
        }
      ]
    }
    """
    return Data(json.utf8)
}

private final class MockMembershipAPI: MembershipAPIServing {
    var userInfo: MembershipUserInfo
    var fetchUserInfoCallCount = 0
    var createOrderCallCount = 0
    var intro: MembershipIntro = MembershipIntro(markdown: "# 会员")
    var orderHistory: [MembershipOrderHistoryItem] = []
    var redeemHistory: [RedeemHistoryItem] = []
    var error: Error?

    init(userInfo: MembershipUserInfo) {
        self.userInfo = userInfo
    }

    func fetchUserInfo() async throws -> MembershipUserInfo {
        fetchUserInfoCallCount += 1
        if let error = error { throw error }
        return userInfo
    }

    func fetchIntro() async throws -> MembershipIntro { intro }

    func createOrder(providerId: String, itemId: String) async throws -> MembershipOrder {
        createOrderCallCount += 1
        if let error = error { throw error }
        return MembershipOrder(orderId: "order-1", orderToken: "token-1", url: "https://example.com/pay")
    }

    func fetchQRCode(orderId: String, orderToken: String) async throws -> MembershipQRCode {
        MembershipQRCode(
            orderId: orderId,
            providerId: "wechat",
            title: "1个月会员",
            totalAmount: "15.00",
            currency: "CNY",
            expireTime: fixedNow.addingTimeInterval(900),
            qrCodeBase64: ""
        )
    }

    func fetchOrderStatus(orderId: String) async throws -> MembershipOrderStatus {
        MembershipOrderStatus(orderId: orderId, isPaid: false)
    }

    func fetchOrderHistory() async throws -> [MembershipOrderHistoryItem] {
        if let error = error { throw error }
        return orderHistory
    }

    func redeem(code: String) async throws -> RedeemResult {
        if let error = error { throw error }
        return RedeemResult(privilege: userInfo.privileges)
    }

    func fetchRedeemHistory() async throws -> [RedeemHistoryItem] {
        if let error = error { throw error }
        return redeemHistory
    }
}

@MainActor
private final class MockEntitlementStore: MembershipEntitlementProviding {
    var cachedUserInfo: MembershipUserInfo?
    var expirations: [Entitlement: Date?] = [:]
    var refreshCallCount = 0
    var refreshError: Error?
    var onRefresh: (() -> Void)?

    func refresh(force: Bool) async throws -> MembershipUserInfo? {
        refreshCallCount += 1
        if let refreshError = refreshError {
            throw refreshError
        }
        onRefresh?()
        return cachedUserInfo
    }

    func entitlementStatus(for entitlement: Entitlement, now: Date) -> EntitlementStatus {
        EntitlementStatus(
            entitlement: entitlement,
            expiresAt: expirations[entitlement] ?? nil,
            now: now
        )
    }
}

// MARK: - 模型 / 时区

final class MembershipModelTests: XCTestCase {
    func testUserInfoDecodesBeijingTimeAndPayConfigs() throws {
        let info = try JSONDecoder().decode(
            MembershipUserInfo.self,
            from: makeUserInfoJSON(
                member: "2027-01-01T00:00:00+08:00",
                resmonitor: "2026-12-01T00:00:00+08:00"
            )
        )

        XCTAssertEqual(info.userId, 123)
        XCTAssertEqual(info.userName, "kaede")
        XCTAssertEqual(info.screenName, "Kaede")
        XCTAssertEqual(info.displayName, "Kaede")
        XCTAssertEqual(info.profileImage, "https://example.com/avatar.png")

        // 北京时间 2027-01-01 00:00 == UTC 2026-12-31 16:00
        XCTAssertEqual(info.privileges.member, membershipDate("2026-12-31T16:00:00Z"))
        XCTAssertEqual(info.privileges.resmonitor, membershipDate("2026-11-30T16:00:00Z"))

        XCTAssertEqual(info.payConfigs.count, 2)
        XCTAssertEqual(info.payConfigs.first?.providerId, "wechat")
        XCTAssertEqual(info.payConfigs.first?.providerName, "微信支付")
        XCTAssertEqual(info.payConfigs.first?.items.count, 4)
        XCTAssertEqual(info.payConfigs.first?.items.first?.price, 1500)
        XCTAssertEqual(info.payConfigs.first?.items.first?.currency, "CNY")
    }

    func testUserInfoMemberStateBeforeAndAfterExpiry() throws {
        let info = try JSONDecoder().decode(
            MembershipUserInfo.self,
            from: makeUserInfoJSON(member: "2026-12-01T00:00:00+08:00")
        )

        XCTAssertTrue(info.isMember(at: membershipDate("2026-11-30T23:59:59+08:00")))
        XCTAssertFalse(info.isMember(at: membershipDate("2026-12-01T00:00:01+08:00")))
        XCTAssertFalse(info.isMember(at: membershipDate("2027-01-01T00:00:00+08:00")))

        let before = info.status(for: .member, at: membershipDate("2026-11-20T00:00:00+08:00"))
        XCTAssertTrue(before.isActive)
        XCTAssertEqual(before.daysRemaining, 11)

        let after = info.status(for: .member, at: membershipDate("2026-12-02T00:00:00+08:00"))
        XCTAssertFalse(after.isActive)
        XCTAssertEqual(after.daysRemaining, 0)
    }

    func testMissingPrivilegesAreTreatedAsInactive() throws {
        let info = try JSONDecoder().decode(
            MembershipUserInfo.self,
            from: Data(#"{"userId":1,"userName":"u"}"#.utf8)
        )
        XCTAssertNil(info.privileges.member)
        XCTAssertFalse(info.isMember(at: fixedNow))
        XCTAssertEqual(info.payConfigs.count, 0)
    }

    func testQRCodeDecodesAndStripsDataURLPrefix() throws {
        // 1x1 GIF（足够验证 base64 解码，不依赖图片格式）。
        let base64 = "R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw=="
        let json = """
        {
          "orderId": "order-1",
          "providerId": "wechat",
          "title": "1个月会员",
          "totalAmount": "15.00",
          "currency": "CNY",
          "expireTime": "2026-11-16T12:15:00+08:00",
          "qrCodeBase64": "data:image/gif;base64,\(base64)"
        }
        """
        let qr = try JSONDecoder().decode(MembershipQRCode.self, from: Data(json.utf8))
        XCTAssertEqual(qr.displayAmount, "¥15.00")
        XCTAssertEqual(qr.expireTime, membershipDate("2026-11-16T04:15:00Z"))
        XCTAssertEqual(qr.qrImageData, Data(base64Encoded: base64))
    }

    func testOrderStatusAndHistoryDecode() throws {
        let statusJSON = """
        {"success":true,"orderId":"order-1","isPaid":true,"memberExpireTime":"2027-01-01T00:00:00+08:00"}
        """
        let status = try JSONDecoder().decode(MembershipOrderStatus.self, from: Data(statusJSON.utf8))
        XCTAssertTrue(status.isPaid)
        XCTAssertEqual(status.memberExpireTime, membershipDate("2026-12-31T16:00:00Z"))

        let orderJSON = """
        {
          "success": true,
          "orderList": [
            {
              "orderId": "202611160001",
              "orderTime": "2026-11-16T10:00:00+08:00",
              "addDays": 30,
              "toTime": "2027-01-01T00:00:00+08:00",
              "title": "1个月会员",
              "description": "微信支付",
              "totalAmount": "15.00",
              "currency": "CNY"
            }
          ]
        }
        """
        let orders = try JSONDecoder().decode(
            MembershipOrderHistoryResponse.self,
            from: Data(orderJSON.utf8)
        )
        XCTAssertEqual(orders.orderList.count, 1)
        XCTAssertEqual(orders.orderList[0].orderId, "202611160001")
        XCTAssertEqual(orders.orderList[0].addDays, 30)
        XCTAssertEqual(orders.orderList[0].displayAmount, "¥15.00")
        XCTAssertEqual(orders.orderList[0].orderTime, membershipDate("2026-11-16T02:00:00Z"))
        XCTAssertEqual(orders.orderList[0].toTime, membershipDate("2026-12-31T16:00:00Z"))

        let redeemJSON = """
        {
          "success": true,
          "redeemList": [
            {
              "redeemTime": "2026-11-16T10:00:00+08:00",
              "promoCode": "ABC123",
              "addDays": 7,
              "toTime": "2026-11-23T00:00:00+08:00",
              "description": "活动赠送"
            }
          ]
        }
        """
        let redeems = try JSONDecoder().decode(
            MembershipRedeemHistoryResponse.self,
            from: Data(redeemJSON.utf8)
        )
        XCTAssertEqual(redeems.redeemList.count, 1)
        XCTAssertEqual(redeems.redeemList[0].promoCode, "ABC123")
        XCTAssertEqual(redeems.redeemList[0].addDays, 7)
        XCTAssertEqual(redeems.redeemList[0].toTime, membershipDate("2026-11-22T16:00:00Z"))

        let redeemResultJSON = """
        {"success":true,"privilege":{"member":"2027-01-01T00:00:00+08:00","resmonitor":null}}
        """
        let result = try JSONDecoder().decode(RedeemResult.self, from: Data(redeemResultJSON.utf8))
        XCTAssertEqual(result.memberExpireDate, membershipDate("2026-12-31T16:00:00Z"))
    }
}

// MARK: - 金额

final class MembershipMoneyTests: XCTestCase {
    func testCentsFormattingForCNY() {
        XCTAssertEqual(MembershipMoney.format(cents: 1500, currency: "CNY"), "¥15.00")
        XCTAssertEqual(MembershipMoney.format(cents: 0, currency: "CNY"), "¥0.00")
        XCTAssertEqual(MembershipMoney.format(cents: 1, currency: "CNY"), "¥0.01")
        XCTAssertEqual(MembershipMoney.format(cents: 123456, currency: "CNY"), "¥1234.56")
    }

    func testTotalAmountFormatting() {
        XCTAssertEqual(MembershipMoney.format(totalAmount: "15.00", currency: "CNY"), "¥15.00")
        XCTAssertEqual(MembershipMoney.format(totalAmount: "15", currency: "CNY"), "¥15.00")
        XCTAssertEqual(MembershipMoney.format(totalAmount: " 12.30 ", currency: "EUR"), "€12.30")
        XCTAssertEqual(MembershipMoney.format(totalAmount: "", currency: "CNY"), "¥")
    }

    func testCurrencySymbolFallback() {
        XCTAssertEqual(MembershipMoney.symbol(for: "CNY"), "¥")
        XCTAssertEqual(MembershipMoney.symbol(for: "USD"), "$")
        XCTAssertEqual(MembershipMoney.symbol(for: "XYZ"), "XYZ ")
    }
}

// MARK: - 支付状态机

final class MembershipPaymentStateMachineTests: XCTestCase {
    private let orderId = "order-1"

    func testWaitingWhenUnpaidAndBeforeDeadline() {
        let state = MembershipPaymentState.waiting(orderId: orderId)
        let next = MembershipPaymentStateMachine.next(
            from: state,
            status: MembershipOrderStatus(orderId: orderId, isPaid: false),
            queryFailed: false,
            now: fixedNow,
            deadline: fixedNow.addingTimeInterval(900),
            orderExpireAt: fixedNow.addingTimeInterval(600)
        )
        XCTAssertEqual(next, .waiting(orderId: orderId))
    }

    func testQueryFailureKeepsWaiting() {
        let state = MembershipPaymentState.waiting(orderId: orderId)
        let next = MembershipPaymentStateMachine.next(
            from: state,
            status: nil,
            queryFailed: true,
            now: fixedNow,
            deadline: fixedNow.addingTimeInterval(900),
            orderExpireAt: fixedNow.addingTimeInterval(600)
        )
        XCTAssertEqual(next, .waiting(orderId: orderId))
    }

    func testPaidWins() {
        let expire = fixedNow.addingTimeInterval(30 * oneDay)
        let next = MembershipPaymentStateMachine.next(
            from: .waiting(orderId: orderId),
            status: MembershipOrderStatus(orderId: orderId, isPaid: true, memberExpireTime: expire),
            queryFailed: false,
            now: fixedNow,
            deadline: fixedNow.addingTimeInterval(900),
            orderExpireAt: fixedNow.addingTimeInterval(600)
        )
        XCTAssertEqual(next, .paid(orderId: orderId, memberExpireAt: expire))
    }

    func testPaidWinsEvenAfterDeadline() {
        let expire = fixedNow.addingTimeInterval(30 * oneDay)
        let next = MembershipPaymentStateMachine.next(
            from: .waiting(orderId: orderId),
            status: MembershipOrderStatus(orderId: orderId, isPaid: true, memberExpireTime: expire),
            queryFailed: false,
            now: fixedNow.addingTimeInterval(901),
            deadline: fixedNow.addingTimeInterval(900),
            orderExpireAt: fixedNow.addingTimeInterval(600)
        )
        XCTAssertEqual(next, .paid(orderId: orderId, memberExpireAt: expire))
    }

    func testOrderExpired() {
        let next = MembershipPaymentStateMachine.next(
            from: .waiting(orderId: orderId),
            status: MembershipOrderStatus(orderId: orderId, isPaid: false),
            queryFailed: false,
            now: fixedNow,
            deadline: fixedNow.addingTimeInterval(900),
            orderExpireAt: fixedNow.addingTimeInterval(-1)
        )
        XCTAssertEqual(next, .timedOut(orderId: orderId, reason: .orderExpired))
    }

    func testPollLimitReached() {
        let next = MembershipPaymentStateMachine.next(
            from: .waiting(orderId: orderId),
            status: nil,
            queryFailed: true,
            now: fixedNow,
            deadline: fixedNow,
            orderExpireAt: nil
        )
        XCTAssertEqual(next, .timedOut(orderId: orderId, reason: .pollLimitReached))
    }

    func testPaidStateIsSticky() {
        let expire = fixedNow.addingTimeInterval(oneDay)
        let state = MembershipPaymentState.paid(orderId: orderId, memberExpireAt: expire)
        let next = MembershipPaymentStateMachine.next(
            from: state,
            status: MembershipOrderStatus(orderId: orderId, isPaid: false),
            queryFailed: true,
            now: fixedNow.addingTimeInterval(9999),
            deadline: fixedNow,
            orderExpireAt: fixedNow.addingTimeInterval(-1)
        )
        XCTAssertEqual(next, state)
    }
}

// MARK: - 权益门禁

@MainActor
final class EntitlementGateTests: XCTestCase {
    func testActiveMemberPassesWithoutPaywall() async {
        let store = MockEntitlementStore()
        store.expirations[.member] = fixedNow.addingTimeInterval(oneDay)
        let gate = EntitlementGate(store: store, now: { fixedNow })

        var loginCalls = 0
        var paywallCalls = 0
        gate.install(
            loginHandler: { _ in loginCalls += 1; return true },
            paywallHandler: { _, _ in paywallCalls += 1; return false }
        )

        let allowed = await gate.require(.member, feature: .aiSummary, presenting: nil)
        XCTAssertTrue(allowed)
        XCTAssertEqual(loginCalls, 1)
        XCTAssertEqual(paywallCalls, 0)
        XCTAssertEqual(store.refreshCallCount, 1)
    }

    func testExpiredMemberShowsPaywallAndPassesAfterPurchase() async {
        let store = MockEntitlementStore()
        store.expirations[.member] = fixedNow.addingTimeInterval(-oneDay)
        let gate = EntitlementGate(store: store, now: { fixedNow })

        var paywallFeature: MembershipFeature?
        gate.install(
            loginHandler: { _ in true },
            paywallHandler: { feature, _ in
                paywallFeature = feature
                store.expirations[.member] = fixedNow.addingTimeInterval(30 * oneDay)
                return true
            }
        )

        let allowed = await gate.require(.member, feature: .aiSummary, presenting: nil)
        XCTAssertTrue(allowed)
        XCTAssertEqual(paywallFeature, .aiSummary)
        XCTAssertEqual(store.refreshCallCount, 2)
    }

    func testExpiredMemberCancelReturnsFalse() async {
        let store = MockEntitlementStore()
        store.expirations[.member] = fixedNow.addingTimeInterval(-oneDay)
        let gate = EntitlementGate(store: store, now: { fixedNow })
        gate.install(loginHandler: { _ in true }, paywallHandler: { _, _ in false })

        let allowed = await gate.require(.member, feature: .backupDanmaku, presenting: nil)
        XCTAssertFalse(allowed)
    }

    func testLoginCancelReturnsFalseWithoutPaywall() async {
        let store = MockEntitlementStore()
        let gate = EntitlementGate(store: store, now: { fixedNow })
        var paywallCalls = 0
        gate.install(
            loginHandler: { _ in false },
            paywallHandler: { _, _ in paywallCalls += 1; return true }
        )

        let allowed = await gate.require(.member, feature: .aiTranslate, presenting: nil)
        XCTAssertFalse(allowed)
        XCTAssertEqual(paywallCalls, 0)
    }

    func testResmonitorIsIndependentFromMember() async {
        let store = MockEntitlementStore()
        store.expirations[.member] = fixedNow.addingTimeInterval(30 * oneDay)
        store.expirations[.resmonitor] = nil
        let gate = EntitlementGate(store: store, now: { fixedNow })

        var paywallCalls = 0
        gate.install(
            loginHandler: { _ in true },
            paywallHandler: { _, _ in
                paywallCalls += 1
                store.expirations[.resmonitor] = fixedNow.addingTimeInterval(oneDay)
                return true
            }
        )

        let allowed = await gate.require(.resmonitor, feature: .resmonitor, presenting: nil)
        XCTAssertTrue(allowed)
        XCTAssertEqual(paywallCalls, 1)
    }

    func testNetworkFailureFallsBackToActiveCache() async {
        let store = MockEntitlementStore()
        store.expirations[.member] = fixedNow.addingTimeInterval(oneDay)
        store.refreshError = URLError(.notConnectedToInternet)
        let gate = EntitlementGate(store: store, now: { fixedNow })
        var paywallCalls = 0
        gate.install(
            loginHandler: { _ in true },
            paywallHandler: { _, _ in paywallCalls += 1; return false }
        )

        let allowed = await gate.require(.member, feature: .aiSummary, presenting: nil)
        XCTAssertTrue(allowed)
        XCTAssertEqual(paywallCalls, 0)
    }
}

// MARK: - MembershipStore 缓存

@MainActor
final class MembershipStoreTests: XCTestCase {
    func testCacheTTLAndForceRefresh() async throws {
        let info = try JSONDecoder().decode(
            MembershipUserInfo.self,
            from: makeUserInfoJSON(member: "2027-01-01T00:00:00+08:00")
        )
        let api = MockMembershipAPI(userInfo: info)
        var clock = fixedNow
        let store = MembershipStore(
            api: api,
            isLoggedIn: { true },
            now: { clock },
            cacheTTL: 60
        )

        let first = try await store.refresh(force: false)
        XCTAssertEqual(first?.userId, 123)
        XCTAssertEqual(api.fetchUserInfoCallCount, 1)
        XCTAssertTrue(store.isMember)

        _ = try await store.refresh(force: false)
        XCTAssertEqual(api.fetchUserInfoCallCount, 1, "60 秒内应命中缓存")

        clock = fixedNow.addingTimeInterval(61)
        _ = try await store.refresh(force: false)
        XCTAssertEqual(api.fetchUserInfoCallCount, 2, "超过 TTL 应重新请求")

        _ = try await store.refresh(force: true)
        XCTAssertEqual(api.fetchUserInfoCallCount, 3, "force 应跳过缓存")
    }

    func testLoggedOutRefreshClearsCache() async throws {
        let info = try JSONDecoder().decode(
            MembershipUserInfo.self,
            from: makeUserInfoJSON(member: "2027-01-01T00:00:00+08:00")
        )
        let api = MockMembershipAPI(userInfo: info)
        var loggedIn = true
        let store = MembershipStore(api: api, isLoggedIn: { loggedIn }, now: { fixedNow })
        _ = try await store.refresh(force: true)
        XCTAssertNotNil(store.cachedUserInfo)

        loggedIn = false
        let result = try await store.refresh(force: true)
        XCTAssertNil(result)
        XCTAssertNil(store.cachedUserInfo)
        XCTAssertFalse(store.isMember)
    }

    func testExpiredMemberIsNotActive() async throws {
        let info = try JSONDecoder().decode(
            MembershipUserInfo.self,
            from: makeUserInfoJSON(member: "2026-01-01T00:00:00+08:00")
        )
        let store = MembershipStore(
            api: MockMembershipAPI(userInfo: info),
            isLoggedIn: { true },
            now: { fixedNow }
        )
        _ = try await store.refresh(force: true)
        XCTAssertFalse(store.isMember)
        XCTAssertEqual(store.entitlementStatus(for: .member, now: fixedNow).daysRemaining, 0)
    }
}

// MARK: - API 200 + success=false

final class MembershipAPITests: XCTestCase {
    private var client: APIClient!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        client = APIClient(session: URLSession(configuration: configuration))
    }

    override func tearDown() {
        StubURLProtocol.handler = nil
        client = nil
        super.tearDown()
    }

    private func makeAPI() -> MembershipAPI {
        let authenticated = AuthenticatedAPIClient(
            client: client,
            tokenProvider: { "token" },
            refreshHandler: { "token-2" }
        )
        return MembershipAPI(
            client: authenticated,
            environment: APIEnvironment(host: "https://api.dandanplay.net", clientId: "test")
        )
    }

    func testBusinessErrorOnHTTP200() async {
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/api/v2/membership/redeem")
            XCTAssertEqual(request.httpMethod, "POST")
            return (
                200,
                ["Content-Type": "application/json"],
                Data(#"{"success":false,"errorMessage":"礼品码不存在","errorCode":3}"#.utf8)
            )
        }

        do {
            _ = try await makeAPI().redeem(code: "ABC123")
            XCTFail("success=false 必须抛错")
        } catch {
            XCTAssertEqual(error.localizedDescription, "礼品码不存在")
        }
    }

    func testOrderStatusPathAndQuery() async throws {
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/api/v2/membership/order/status")
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
            XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "orderId" })?.value, "order-1")
            return (
                200,
                ["Content-Type": "application/json"],
                Data(#"{"success":true,"orderId":"order-1","isPaid":false,"memberExpireTime":null}"#.utf8)
            )
        }

        let status = try await makeAPI().fetchOrderStatus(orderId: "order-1")
        XCTAssertEqual(status.orderId, "order-1")
        XCTAssertFalse(status.isPaid)
    }

    func testFetchUserInfoUsesBearerAndDecodes() async throws {
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/api/v2/user/me")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token")
            return (
                200,
                ["Content-Type": "application/json"],
                makeUserInfoJSON(member: "2027-01-01T00:00:00+08:00")
            )
        }

        let info = try await makeAPI().fetchUserInfo()
        XCTAssertEqual(info.userId, 123)
        XCTAssertEqual(info.privileges.member, membershipDate("2026-12-31T16:00:00Z"))
    }
}

// MARK: - 礼品码清洗

final class MembershipPromoCodeTests: XCTestCase {
    func testSanitize() {
        XCTAssertEqual(MembershipPromoCode.sanitized(" AB-CD EF-GH "), "ABCDEFGH")
        XCTAssertEqual(
            MembershipPromoCode.sanitized("ABCDEFGHIJ-KLMNOPQRST-UVWX"),
            "ABCDEFGHIJKLMNOPQRST"
        )
        XCTAssertEqual(MembershipPromoCode.maxLength, 20)
    }
}

// MARK: - 支付表单防重复下单

@MainActor
final class MembershipViewModelPaymentGuardTests: XCTestCase {
    private func makeViewModel() async throws -> (MembershipViewModel, MockMembershipAPI) {
        let info = try JSONDecoder().decode(
            MembershipUserInfo.self,
            from: makeUserInfoJSON(member: "2026-12-31T16:00:00Z")
        )
        let api = MockMembershipAPI(userInfo: info)
        let store = MembershipStore(
            api: api,
            isLoggedIn: { true },
            now: { fixedNow }
        )
        _ = try await store.refresh(force: true)

        let viewModel = MembershipViewModel(
            feature: nil,
            api: api,
            store: store,
            now: { fixedNow },
            // 单测不能启动系统浏览器；mock 订单的 example.com/pay 只用于验证降级路径。
            openURL: { _ in true }
        )
        viewModel.begin()
        return (viewModel, api)
    }

    func testRepeatedStartPaymentCreatesOneOrder() async throws {
        let (viewModel, api) = try await makeViewModel()
        XCTAssertNotNil(viewModel.selectedItem)

        viewModel.startPayment()
        viewModel.startPayment()
        XCTAssertEqual(viewModel.paymentState, .creating)

        var waited = 0
        while api.createOrderCallCount == 0 && waited < 100 {
            try await Task.sleep(nanoseconds: 10_000_000)
            waited += 1
        }
        XCTAssertEqual(api.createOrderCallCount, 1)
        viewModel.stopAll()
    }

    func testChangingSelectionReturnsToFormAndIgnoresLatePaymentResult() async throws {
        let (viewModel, api) = try await makeViewModel()
        XCTAssertNotNil(viewModel.selectedItem)

        viewModel.startPayment()
        XCTAssertEqual(viewModel.paymentState, .creating)

        var waited = 0
        while api.createOrderCallCount == 0 && waited < 100 {
            try await Task.sleep(nanoseconds: 10_000_000)
            waited += 1
        }

        viewModel.selectItem(id: "wechat12m")
        XCTAssertEqual(viewModel.paymentState, .idle)
        XCTAssertEqual(viewModel.selectedItem?.id, "wechat12m")

        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(viewModel.paymentState, .idle)
        viewModel.stopAll()
    }
}
