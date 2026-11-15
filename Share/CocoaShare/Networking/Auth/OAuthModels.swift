//
//  OAuthModels.swift
//  AniXPlayer
//
//  macOS only：OAuth token 与用户资料模型。
//

import Foundation

enum OAuthTokenError: LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return NSLocalizedString("登录服务返回了无效的凭证", comment: "")
        }
    }
}

/// `/oauth/token` 的原始响应（snake_case）。
struct OAuthTokenResponse: Decodable {
    let accessToken: String
    let tokenType: String?
    let expiresIn: Int
    let refreshToken: String
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }
}

/// 内存中的 token；access token 不落盘，refresh token 只进 Keychain。
struct OAuthToken: Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let scope: String?

    func isExpiring(within leeway: TimeInterval = 300, now: Date = Date()) -> Bool {
        expiresAt.timeIntervalSince(now) <= leeway
    }

    static func make(from response: OAuthTokenResponse, now: Date = Date()) throws -> OAuthToken {
        guard !response.accessToken.isEmpty,
              response.expiresIn > 0,
              !response.refreshToken.isEmpty else {
            throw OAuthTokenError.invalidResponse
        }
        return OAuthToken(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresAt: now.addingTimeInterval(TimeInterval(response.expiresIn)),
            scope: response.scope
        )
    }
}

/// 用户权益（时间是带时区的 ISO8601，例如 `2027-01-01T00:00:00+08:00`）。
struct OAuthPrivileges: Decodable, Equatable {
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

    private static func decodeDate(_ container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Date? {
        guard let string = try? container.decodeIfPresent(String.self, forKey: key) else { return nil }
        return DDPDateParser.parse(string)
    }
}

/// `/user/me` 的模型（只保留本阶段需要的字段）。
struct OAuthUserProfile: Decodable, Equatable {
    let userId: Int
    let userName: String
    let screenName: String
    let email: String?
    let emailVerified: Bool
    let profileImage: String
    let accountTier: String?
    let appScope: String?
    let privileges: OAuthPrivileges?

    enum CodingKeys: String, CodingKey {
        case userId
        case userName
        case screenName
        case email
        case emailVerified
        case profileImage
        case accountTier
        case appScope
        case privileges
    }

    init(
        userId: Int = 0,
        userName: String = "",
        screenName: String = "",
        email: String? = nil,
        emailVerified: Bool = false,
        profileImage: String = "",
        accountTier: String? = nil,
        appScope: String? = nil,
        privileges: OAuthPrivileges? = nil
    ) {
        self.userId = userId
        self.userName = userName
        self.screenName = screenName
        self.email = email
        self.emailVerified = emailVerified
        self.profileImage = profileImage
        self.accountTier = accountTier
        self.appScope = appScope
        self.privileges = privileges
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.userId = try container.decodeIfPresent(Int.self, forKey: .userId) ?? 0
        self.userName = try container.decodeIfPresent(String.self, forKey: .userName) ?? ""
        self.screenName = try container.decodeIfPresent(String.self, forKey: .screenName) ?? ""
        self.email = try container.decodeIfPresent(String.self, forKey: .email)
        self.emailVerified = try container.decodeIfPresent(Bool.self, forKey: .emailVerified) ?? false
        self.profileImage = try container.decodeIfPresent(String.self, forKey: .profileImage) ?? ""
        self.accountTier = try container.decodeIfPresent(String.self, forKey: .accountTier)
        self.appScope = try container.decodeIfPresent(String.self, forKey: .appScope)
        self.privileges = try container.decodeIfPresent(OAuthPrivileges.self, forKey: .privileges)
    }

    var displayName: String {
        if !screenName.isEmpty { return screenName }
        if !userName.isEmpty { return userName }
        return userId > 0 ? String(format: NSLocalizedString("用户 %d", comment: ""), userId) : NSLocalizedString("已登录用户", comment: "")
    }

    var isMember: Bool {
        guard let member = privileges?.member else { return false }
        return member > Date()
    }
}

enum DDPDateParser {
    private static let internetDateTime: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let internetDateTimeWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func parse(_ string: String) -> Date? {
        if let date = internetDateTime.date(from: string) {
            return date
        }
        if let date = internetDateTimeWithFractionalSeconds.date(from: string) {
            return date
        }
        return DateFormatter.anix_YYYY_MM_dd_T_HH_mm_ssFormatter.date(from: string)
    }
}
