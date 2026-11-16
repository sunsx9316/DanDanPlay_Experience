//
//  OAuthCallback.swift
//  AniXPlayer
//
//  macOS only：授权回调 URL 的匹配、state 校验与 code 解析。
//

import Foundation

/// 一次授权事务；有效期 10 分钟、一次性。
struct OAuthTransaction: Equatable {
    static let lifetime: TimeInterval = 10 * 60

    let state: String
    let verifier: String
    let redirectURI: String
    let createdAt: Date

    init(state: String, verifier: String, redirectURI: String, createdAt: Date = Date()) {
        self.state = state
        self.verifier = verifier
        self.redirectURI = redirectURI
        self.createdAt = createdAt
    }

    func isExpired(now: Date = Date()) -> Bool {
        now.timeIntervalSince(createdAt) >= Self.lifetime
    }
}

enum OAuthCallbackError: LocalizedError {
    case invalidRedirectURI
    case expired
    case stateMismatch
    case authorizationDenied(String)
    case missingCode

    var errorDescription: String? {
        switch self {
        case .invalidRedirectURI:
            return NSLocalizedString("登录回调地址无效", comment: "")
        case .expired:
            return NSLocalizedString("登录已超时，请重新登录", comment: "")
        case .stateMismatch:
            return NSLocalizedString("登录校验失败，请重新登录", comment: "")
        case .authorizationDenied(let message):
            return message.isEmpty ? NSLocalizedString("登录失败，请重试", comment: "") : message
        case .missingCode:
            return NSLocalizedString("登录回调缺少授权码，请重新登录", comment: "")
        }
    }
}

enum OAuthCallback {
    /// 严格比较 scheme/host/port/path（忽略 query/fragment）。
    static func matches(_ url: URL, redirectURI: String) -> Bool {
        guard let expected = URLComponents(string: redirectURI),
              let actual = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return false
        }

        return actual.scheme?.lowercased() == expected.scheme?.lowercased()
            && actual.host?.lowercased() == expected.host?.lowercased()
            && actual.port == expected.port
            && actual.path == expected.path
    }

    /// 校验并返回授权码。
    static func parse(_ url: URL, expected: OAuthTransaction, now: Date = Date()) throws -> String {
        guard matches(url, redirectURI: expected.redirectURI),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw OAuthCallbackError.invalidRedirectURI
        }

        guard !expected.isExpired(now: now) else {
            throw OAuthCallbackError.expired
        }

        let queryItems = components.queryItems ?? []
        let state = queryItems.first(where: { $0.name == "state" })?.value
        guard state == expected.state else {
            throw OAuthCallbackError.stateMismatch
        }

        if let error = queryItems.first(where: { $0.name == "error" })?.value {
            let description = queryItems.first(where: { $0.name == "error_description" })?.value
            let message = description?.isEmpty == false ? description! : error
            throw OAuthCallbackError.authorizationDenied(message)
        }

        guard let code = queryItems.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw OAuthCallbackError.missingCode
        }

        return code
    }
}
