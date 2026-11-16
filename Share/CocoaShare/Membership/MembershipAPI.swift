//
//  MembershipAPI.swift
//  AniXPlayer
//
//  macOS only：会员相关 API。
//
//  - 全部走 AuthenticatedAPIClient（Bearer + 401 单次刷新）；
//  - APIEnvironment.makeURL 自动加 `/api/v2`；
//  - 服务端可能以 200 + `success=false` 返回业务错误，这里统一抛 MembershipAPIError。
//

import Foundation

protocol MembershipAPIServing: AnyObject {
    func fetchUserInfo() async throws -> MembershipUserInfo
    func fetchIntro() async throws -> MembershipIntro
    func createOrder(providerId: String, itemId: String) async throws -> MembershipOrder
    func fetchQRCode(orderId: String, orderToken: String) async throws -> MembershipQRCode
    func fetchOrderStatus(orderId: String) async throws -> MembershipOrderStatus
    func fetchOrderHistory() async throws -> [MembershipOrderHistoryItem]
    func redeem(code: String) async throws -> RedeemResult
    func fetchRedeemHistory() async throws -> [RedeemHistoryItem]
}

final class MembershipAPI: MembershipAPIServing {
    private let client: AuthenticatedAPIClient
    private let environment: APIEnvironment
    private let decoder: JSONDecoder

    init(
        client: AuthenticatedAPIClient = AuthenticatedAPIClient(),
        environment: APIEnvironment = .current()
    ) {
        self.client = client
        self.environment = environment
        self.decoder = JSONDecoder()
    }

    // MARK: - Endpoints

    func fetchUserInfo() async throws -> MembershipUserInfo {
        try await get("/user/me")
    }

    func fetchIntro() async throws -> MembershipIntro {
        try await get("/membership/intro")
    }

    func createOrder(providerId: String, itemId: String) async throws -> MembershipOrder {
        let body = CreateOrderBody(providerId: providerId, itemId: itemId)
        return try await post("/membership/order", body: body)
    }

    func fetchQRCode(orderId: String, orderToken: String) async throws -> MembershipQRCode {
        try await get(
            "/pay/qrcode",
            queryItems: [
                URLQueryItem(name: "orderId", value: orderId),
                URLQueryItem(name: "orderToken", value: orderToken)
            ]
        )
    }

    func fetchOrderStatus(orderId: String) async throws -> MembershipOrderStatus {
        try await get(
            "/membership/order/status",
            queryItems: [URLQueryItem(name: "orderId", value: orderId)]
        )
    }

    func fetchOrderHistory() async throws -> [MembershipOrderHistoryItem] {
        let response: MembershipOrderHistoryResponse = try await get("/membership/order/history")
        return response.orderList
    }

    func redeem(code: String) async throws -> RedeemResult {
        let body = RedeemBody(promoCode: code)
        return try await post("/membership/redeem", body: body)
    }

    func fetchRedeemHistory() async throws -> [RedeemHistoryItem] {
        let response: MembershipRedeemHistoryResponse = try await get("/membership/redeem/history")
        return response.redeemList
    }

    // MARK: - Request helpers

    private func get<T: Decodable>(_ path: String, queryItems: [URLQueryItem] = []) async throws -> T {
        let url = try makeURL(path: path, queryItems: queryItems)
        let request = APIClient.jsonRequest(
            url: url,
            method: .get,
            userAgent: environment.userAgent
        )
        return try await send(request)
    }

    private func post<T: Decodable, Body: Encodable>(_ path: String, body: Body) async throws -> T {
        let url = try makeURL(path: path)
        let data: Data
        do {
            data = try JSONEncoder().encode(body)
        } catch {
            throw APIError.decoding(error)
        }
        let request = APIClient.jsonRequest(
            url: url,
            method: .post,
            body: data,
            userAgent: environment.userAgent
        )
        return try await send(request)
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data = try await client.send(request)
        try validateStatusEnvelope(in: data)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    private func makeURL(path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        guard let baseURL = environment.makeURL(path) else {
            throw APIError.invalidURL
        }
        guard !queryItems.isEmpty else {
            return baseURL
        }
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        components.queryItems = queryItems
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        return url
    }

    /// 只为 `success=false` 抛错；缺失 success 的旧响应按成功处理。
    private func validateStatusEnvelope(in data: Data) throws {
        guard let status = try? decoder.decode(MembershipResponseStatus.self, from: data),
              status.isFailure else {
            return
        }
        throw MembershipAPIError.server(
            message: status.displayMessage ?? NSLocalizedString("操作失败，请稍后重试", comment: ""),
            code: status.errorCode
        )
    }

    private struct CreateOrderBody: Encodable {
        let providerId: String
        let itemId: String
    }

    private struct RedeemBody: Encodable {
        let promoCode: String
    }
}
