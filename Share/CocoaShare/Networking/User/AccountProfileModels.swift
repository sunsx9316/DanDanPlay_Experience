//
//  AccountProfileModels.swift
//  AniXPlayer
//
//  macOS only：账号资料修改的请求模型、校验与关联状态。
//

import Foundation

// MARK: - Requests

struct AccountUpdateScreenNameRequest: Encodable, Equatable {
    let screenName: String
}

struct AccountUpdateEmailRequest: Encodable, Equatable {
    let oldEmail: String
    let newEmail: String
}

struct AccountUpdatePasswordRequest: Encodable, Equatable {
    let oldPassword: String
    let newPassword: String
}

// MARK: - Responses

struct AccountUpdateResponse: Decodable, Equatable {
    let success: Bool?
    let errorCode: Int?
    let errorMessage: String?

    var didSucceed: Bool {
        if let success = success {
            return success
        }
        return (errorCode ?? 0) == 0
    }
}

struct AccountWebTokenResponse: Decodable, Equatable {
    let success: Bool?
    let errorCode: Int?
    let errorMessage: String?
    let webToken: String?
    let business: String?

    var didSucceed: Bool {
        if let success = success {
            return success
        }
        return (errorCode ?? 0) == 0
    }
}

struct AccountOAuthProviderLoginResponse: Decodable, Equatable {
    let success: Bool?
    let errorCode: Int?
    let errorMessage: String?
    let state: String?
    let url: String?

    var didSucceed: Bool {
        if let success = success {
            return success
        }
        return (errorCode ?? 0) == 0
    }
}

enum AccountProfileBusiness {
    static let emailVerify = "email_verify"
    static let oauthBangumi = "oauth_bangumi"
}

// MARK: - Validation

enum AccountProfileValidationError: LocalizedError, Equatable {
    case emptyScreenName
    case invalidScreenNameLength
    case invalidOldEmail
    case invalidNewEmail
    case unchangedEmail
    case invalidOldPassword
    case invalidNewPassword
    case passwordMismatch
    case unchangedPassword

    var errorDescription: String? {
        switch self {
        case .emptyScreenName:
            return NSLocalizedString("昵称不能为空", comment: "")
        case .invalidScreenNameLength:
            return NSLocalizedString("昵称长度需为 1–50 个字符", comment: "")
        case .invalidOldEmail:
            return NSLocalizedString("请输入有效的当前邮箱", comment: "")
        case .invalidNewEmail:
            return NSLocalizedString("请输入有效的新邮箱", comment: "")
        case .unchangedEmail:
            return NSLocalizedString("新邮箱不能与当前邮箱相同", comment: "")
        case .invalidOldPassword:
            return NSLocalizedString("当前密码长度需为 5–20 位", comment: "")
        case .invalidNewPassword:
            return NSLocalizedString("新密码长度需为 5–20 位", comment: "")
        case .passwordMismatch:
            return NSLocalizedString("两次输入的新密码不一致", comment: "")
        case .unchangedPassword:
            return NSLocalizedString("新密码不能与当前密码相同", comment: "")
        }
    }
}

enum AccountProfileValidator {

    static func screenName(_ raw: String) throws -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            throw AccountProfileValidationError.emptyScreenName
        }
        guard (1...50).contains(value.count) else {
            throw AccountProfileValidationError.invalidScreenNameLength
        }
        return value
    }

    static func email(_ raw: String) throws -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidEmail(value) else {
            throw AccountProfileValidationError.invalidNewEmail
        }
        return value
    }

    static func emailChange(old rawOld: String, new rawNew: String) throws -> (old: String, new: String) {
        let old = rawOld.trimmingCharacters(in: .whitespacesAndNewlines)
        let new = rawNew.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidEmail(old) else {
            throw AccountProfileValidationError.invalidOldEmail
        }
        guard isValidEmail(new) else {
            throw AccountProfileValidationError.invalidNewEmail
        }
        guard old.caseInsensitiveCompare(new) != .orderedSame else {
            throw AccountProfileValidationError.unchangedEmail
        }
        return (old, new)
    }

    static func passwordChange(
        old: String,
        new: String,
        confirmation: String
    ) throws -> (old: String, new: String) {
        guard (5...20).contains(old.count) else {
            throw AccountProfileValidationError.invalidOldPassword
        }
        guard (5...20).contains(new.count) else {
            throw AccountProfileValidationError.invalidNewPassword
        }
        guard new == confirmation else {
            throw AccountProfileValidationError.passwordMismatch
        }
        guard old != new else {
            throw AccountProfileValidationError.unchangedPassword
        }
        return (old, new)
    }

    static func isValidEmail(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 254 else { return false }
        let pattern = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#
        return value.range(of: pattern, options: .regularExpression) != nil
    }
}

// MARK: - bangumi.tv link state

enum AccountBangumiLinkStatus: Equatable {
    case notLinked
    case linked
    case expired
}

struct AccountBangumiLinkState: Equatable {
    let account: OAuthLinkedAccount?
    let status: AccountBangumiLinkStatus

    init(account: OAuthLinkedAccount?, now: Date = Date()) {
        self.account = account
        if let account = account {
            self.status = account.isExpired(now: now) ? .expired : .linked
        } else {
            self.status = .notLinked
        }
    }

    var isLinked: Bool {
        status != .notLinked
    }

    var needsAuthorization: Bool {
        status != .linked
    }
}
