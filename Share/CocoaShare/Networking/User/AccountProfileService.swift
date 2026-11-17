//
//  AccountProfileService.swift
//  AniXPlayer
//
//  macOS only：账号资料、邮箱、密码与 bangumi.tv 关联相关请求。
//

import Foundation

enum AccountProfileServiceError: LocalizedError {
    case invalidEndpoint
    case missingWebToken
    case missingAuthorizationURL
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return NSLocalizedString("账号服务地址无效", comment: "")
        case .missingWebToken:
            return NSLocalizedString("未能获取临时授权凭证，请稍后重试", comment: "")
        case .missingAuthorizationURL:
            return NSLocalizedString("未能获取 bangumi.tv 授权地址", comment: "")
        case .server(let message):
            return message
        }
    }
}

protocol AccountProfileServicing {
    func updateScreenName(_ screenName: String) async throws
    func updateEmail(oldEmail: String, newEmail: String) async throws
    func updatePassword(oldPassword: String, newPassword: String) async throws
    func fetchWebToken(business: String) async throws -> String
    func fetchBangumiAuthorizationURL() async throws -> URL
    func makeEmailVerificationURL(webToken: String) -> URL?
    func makeBangumiManagementURL(webToken: String) -> URL?
}

final class AccountProfileService: AccountProfileServicing {

    let environment: APIEnvironment
    let client: AuthenticatedAPIClient
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(
        environment: APIEnvironment = .current(),
        client: AuthenticatedAPIClient = AuthenticatedAPIClient()
    ) {
        self.environment = environment
        self.client = client
    }

    // MARK: - Updates

    func updateScreenName(_ screenName: String) async throws {
        guard let url = environment.userProfileUpdateEndpoint else {
            throw AccountProfileServiceError.invalidEndpoint
        }
        let body = try encoder.encode(AccountUpdateScreenNameRequest(screenName: screenName))
        try await sendUpdate(makeJSONRequest(url: url, method: .post, body: body))
    }

    func updateEmail(oldEmail: String, newEmail: String) async throws {
        guard let url = environment.userEmailUpdateEndpoint else {
            throw AccountProfileServiceError.invalidEndpoint
        }
        let body = try encoder.encode(AccountUpdateEmailRequest(oldEmail: oldEmail, newEmail: newEmail))
        try await sendUpdate(makeJSONRequest(url: url, method: .post, body: body))
    }

    func updatePassword(oldPassword: String, newPassword: String) async throws {
        guard let url = environment.userPasswordUpdateEndpoint else {
            throw AccountProfileServiceError.invalidEndpoint
        }
        let body = try encoder.encode(AccountUpdatePasswordRequest(
            oldPassword: oldPassword,
            newPassword: newPassword
        ))
        try await sendUpdate(makeJSONRequest(url: url, method: .post, body: body))
    }

    // MARK: - Temporary web tokens

    func fetchWebToken(business: String) async throws -> String {
        guard let endpoint = environment.webTokenEndpoint,
              let url = Self.appendingQuery(to: endpoint, items: [
                URLQueryItem(name: "business", value: business)
              ]) else {
            throw AccountProfileServiceError.invalidEndpoint
        }
        let response: AccountWebTokenResponse = try await send(makeJSONRequest(url: url, method: .get))
        guard response.didSucceed else {
            throw AccountProfileServiceError.server(response.errorMessage ?? genericFailureMessage)
        }
        guard let token = response.webToken, !token.isEmpty else {
            throw AccountProfileServiceError.missingWebToken
        }
        return token
    }

    func fetchBangumiAuthorizationURL() async throws -> URL {
        guard let endpoint = environment.oauthProviderLoginEndpoint(provider: "bangumi"),
              let url = Self.appendingQuery(to: endpoint, items: [
                URLQueryItem(name: "redirectUrl", value: "")
              ]) else {
            throw AccountProfileServiceError.invalidEndpoint
        }
        let response: AccountOAuthProviderLoginResponse = try await send(makeJSONRequest(url: url, method: .get))
        guard response.didSucceed else {
            throw AccountProfileServiceError.server(response.errorMessage ?? genericFailureMessage)
        }
        guard let rawURL = response.url,
              let authorizationURL = URL(string: rawURL),
              let scheme = authorizationURL.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else {
            throw AccountProfileServiceError.missingAuthorizationURL
        }
        return authorizationURL
    }

    func makeEmailVerificationURL(webToken: String) -> URL? {
        guard let endpoint = environment.emailVerifyPageEndpoint else { return nil }
        return Self.appendingQuery(to: endpoint, items: [
            URLQueryItem(name: "webToken", value: webToken)
        ])
    }

    func makeBangumiManagementURL(webToken: String) -> URL? {
        guard let endpoint = environment.oauthProviderManageEndpoint(provider: "bangumi") else { return nil }
        return Self.appendingQuery(to: endpoint, items: [
            URLQueryItem(name: "webToken", value: webToken)
        ])
    }

    // MARK: - Helpers

    private var genericFailureMessage: String {
        NSLocalizedString("操作失败，请稍后重试", comment: "")
    }

    private func makeJSONRequest(url: URL, method: HTTPMethod, body: Data? = nil) -> URLRequest {
        APIClient.jsonRequest(
            url: url,
            method: method,
            body: body,
            userAgent: environment.userAgent,
            timeout: environment.timeout
        )
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data = try await client.send(request)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    private func sendUpdate(_ request: URLRequest) async throws {
        let data: Data = try await client.send(request)
        guard !data.isEmpty else { return }
        guard let response = try? decoder.decode(AccountUpdateResponse.self, from: data) else {
            return
        }
        guard response.didSucceed else {
            throw AccountProfileServiceError.server(response.errorMessage ?? genericFailureMessage)
        }
    }

    static func appendingQuery(to url: URL, items: [URLQueryItem]) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        var queryItems = components.queryItems ?? []
        queryItems.append(contentsOf: items)
        components.queryItems = queryItems
        return components.url
    }
}
