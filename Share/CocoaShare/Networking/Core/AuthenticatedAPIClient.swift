//
//  AuthenticatedAPIClient.swift
//  AniXPlayer
//
//  macOS only：带 Bearer 注入与 401 单次刷新重试的 API 客户端。
//

import Foundation

final class AuthenticatedAPIClient {
    typealias TokenProvider = () async throws -> String
    typealias RefreshHandler = () async throws -> String

    private let client: APIClient
    private let tokenProvider: TokenProvider
    private let refreshHandler: RefreshHandler

    init(
        client: APIClient = APIClient(),
        tokenProvider: @escaping TokenProvider,
        refreshHandler: @escaping RefreshHandler
    ) {
        self.client = client
        self.tokenProvider = tokenProvider
        self.refreshHandler = refreshHandler
    }

    convenience init(client: APIClient = APIClient(), session: SessionStore = .shared) {
        self.init(
            client: client,
            tokenProvider: { try await session.validAccessToken() },
            refreshHandler: { try await session.forceRefresh().accessToken }
        )
    }

    func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data = try await send(request)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func send(_ request: URLRequest) async throws -> Data {
        var authorized = request
        let token = try await tokenProvider()
        authorized.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            return try await client.send(authorized)
        } catch let error as APIError where error.isUnauthorized {
            // 只重试一次：刷新后仍 401，交给调用方处理并避免刷新风暴。
            let newToken = try await refreshHandler()
            authorized.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
            return try await client.send(authorized)
        }
    }
}
