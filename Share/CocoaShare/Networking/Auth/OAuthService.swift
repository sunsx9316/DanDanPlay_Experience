//
//  OAuthService.swift
//  AniXPlayer
//
//  macOS only：OAuth 授权、token 交换/刷新/撤销、用户资料。
//

import Foundation

enum OAuthServiceError: LocalizedError {
    case invalidEndpoint
    case profileDecoding

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return NSLocalizedString("登录服务地址无效", comment: "")
        case .profileDecoding:
            return NSLocalizedString("用户资料格式不正确", comment: "")
        }
    }
}

protocol OAuthServicing {
    var environment: APIEnvironment { get }
    func makeAuthorizeRequest(now: Date) -> (url: URL, transaction: OAuthTransaction)
    func exchangeCode(_ code: String, transaction: OAuthTransaction) async throws -> OAuthToken
    func refresh(refreshToken: String) async throws -> OAuthToken
    func revoke(refreshToken: String) async
    func logout(accessToken: String) async
    func fetchProfile(accessToken: String) async throws -> OAuthUserProfile
}

extension OAuthServicing {
    func makeAuthorizeRequest() -> (url: URL, transaction: OAuthTransaction) {
        makeAuthorizeRequest(now: Date())
    }
}

final class OAuthService: OAuthServicing {
    let environment: APIEnvironment
    let client: APIClient

    init(environment: APIEnvironment = .current(), client: APIClient = APIClient()) {
        self.environment = environment
        self.client = client
    }

    /// 生成 authorize URL 与一次事务（state/verifier/redirect_uri）。
    func makeAuthorizeRequest(now: Date = Date()) -> (url: URL, transaction: OAuthTransaction) {
        let pkce = OAuthPKCE.makePair()
        let state = OAuthPKCE.randomURLSafeString(byteCount: 16)
        let redirectURI = environment.redirectURI

        guard let endpoint = environment.authorizeEndpoint,
              var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            preconditionFailure("invalid authorize endpoint")
        }

        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: environment.clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        guard let url = components.url else {
            preconditionFailure("invalid authorize url")
        }

        let transaction = OAuthTransaction(
            state: state,
            verifier: pkce.verifier,
            redirectURI: redirectURI,
            createdAt: now
        )
        return (url, transaction)
    }

    func exchangeCode(_ code: String, transaction: OAuthTransaction) async throws -> OAuthToken {
        let request = tokenRequest(fields: [
            "grant_type": "authorization_code",
            "client_id": environment.clientId,
            "code": code,
            "redirect_uri": transaction.redirectURI,
            "code_verifier": transaction.verifier
        ])
        let response: OAuthTokenResponse = try await client.send(request)
        return try OAuthToken.make(from: response)
    }

    func refresh(refreshToken: String) async throws -> OAuthToken {
        let request = tokenRequest(fields: [
            "grant_type": "refresh_token",
            "client_id": environment.clientId,
            "refresh_token": refreshToken
        ])
        let response: OAuthTokenResponse = try await client.send(request)
        return try OAuthToken.make(from: response)
    }

    /// 撤销 refresh token；失败不阻塞本地登出。
    func revoke(refreshToken: String) async {
        guard environment.revokeEndpoint != nil else { return }
        let request = APIClient.formRequest(
            url: environment.revokeEndpoint,
            fields: [
                "client_id": environment.clientId,
                "token": refreshToken,
                "token_type_hint": "refresh_token"
            ],
            userAgent: environment.userAgent,
            timeout: environment.timeout
        )
        _ = try? await client.send(request)
    }

    /// 服务端登出；失败不阻塞本地登出。
    func logout(accessToken: String) async {
        guard environment.logoutEndpoint != nil else { return }
        let request = APIClient.formRequest(
            url: environment.logoutEndpoint,
            fields: [:],
            bearerToken: accessToken,
            userAgent: environment.userAgent,
            timeout: environment.timeout
        )
        _ = try? await client.send(request)
    }

    func fetchProfile(accessToken: String) async throws -> OAuthUserProfile {
        guard let endpoint = environment.userMeEndpoint else {
            throw OAuthServiceError.invalidEndpoint
        }
        let request = APIClient.jsonRequest(
            url: endpoint,
            bearerToken: accessToken,
            userAgent: environment.userAgent,
            timeout: environment.timeout
        )
        let data = try await client.send(request)

        let decoder = JSONDecoder()
        if let profile = try? decoder.decode(OAuthUserProfile.self, from: data) {
            return profile
        }
        if let envelope = try? decoder.decode(ProfileEnvelope.self, from: data) {
            return envelope.result
        }
        throw OAuthServiceError.profileDecoding
    }

    private func tokenRequest(fields: [String: String]) -> URLRequest {
        APIClient.formRequest(
            url: environment.tokenEndpoint,
            fields: fields,
            userAgent: environment.userAgent,
            timeout: environment.timeout
        )
    }

    private struct ProfileEnvelope: Decodable {
        let result: OAuthUserProfile
    }
}
