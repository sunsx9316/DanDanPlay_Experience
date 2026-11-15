//
//  APIEnvironment.swift
//  AniXPlayer
//
//  macOS only：OAuth / API 端环境配置。
//

import Foundation

/// OAuth client_id。
///
/// 联调期复用 Windows 的 `ddplaywin32v3`；正式发布前必须替换为 macOS 专属 client，
/// 并在两个 auth host 上登记同路径回调。见 `docs/04-auth-oauth-migration.md` §3.6。
enum OAuthClientIdentity {
    /// 开发/联调期使用的 client（已实测可授权）。
    static let developmentClientId = "ddplaywin32v3"

    /// 正式 macOS client。注册完成前暂时与开发期一致。
    static let productionClientId = "ddplaywin32v3"

    static var current: String {
        if let override = ProcessInfo.processInfo.environment["DDP_OAUTH_CLIENT_ID"],
           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return override
        }
        return productionClientId
    }
}

struct APIEnvironment {
    let host: String
    let clientId: String
    var apiVersion: String = "/api/v2"
    var timeout: TimeInterval = 20
    var userAgent: String = "dandanplay/macos \(AppInfoHelper.appVersion)"

    init(host: String, clientId: String) {
        var normalized = host.trimmingCharacters(in: .whitespacesAndNewlines)
        while normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        self.host = normalized.isEmpty ? DefaultHost : normalized
        self.clientId = clientId
    }

    static func current(
        host: String = Preferences.shared.host,
        clientId: String = OAuthClientIdentity.current
    ) -> APIEnvironment {
        APIEnvironment(host: host, clientId: clientId)
    }

    var baseURL: URL {
        URL(string: host) ?? URL(string: DefaultHost)!
    }

    func makeURL(_ path: String) -> URL? {
        let suffix = path.hasPrefix("/") ? path : "/" + path
        return URL(string: host + apiVersion + suffix)
    }

    /// 同源 HTTPS 哨兵回调；必须与 client 登记的 redirect_uri 完全一致。
    var redirectURI: String {
        host + apiVersion + "/oauth/callback/app/" + clientId
    }

    var authorizeEndpoint: URL! { makeURL("/oauth/authorize") }
    var tokenEndpoint: URL! { makeURL("/oauth/token") }
    var revokeEndpoint: URL! { makeURL("/oauth/revoke") }
    var logoutEndpoint: URL! { makeURL("/oauth/logout") }
    var userMeEndpoint: URL! { makeURL("/user/me") }
}
