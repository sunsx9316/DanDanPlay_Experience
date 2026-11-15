//
//  APIError.swift
//  AniXPlayer
//
//  macOS only：新的网络层错误模型。
//

import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case transport(Error)
    case cancelled
    case http(status: Int, message: String?)
    case unauthorized
    case forbidden(message: String?)
    case rateLimited(retryAfter: TimeInterval?)
    case oauth(code: String, description: String?, status: Int)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return NSLocalizedString("请求地址无效", comment: "")
        case .transport(let error):
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet, .networkConnectionLost:
                    return NSLocalizedString("无法连接弹弹play，请检查网络后重试", comment: "")
                case .timedOut:
                    return NSLocalizedString("请求超时，请稍后重试", comment: "")
                case .cancelled:
                    return nil
                default:
                    break
                }
            }
            return error.localizedDescription
        case .cancelled:
            return nil
        case .http(let status, let message):
            if let message = message, !message.isEmpty {
                return message
            }
            return String(format: NSLocalizedString("服务暂时不可用（%d），请稍后重试", comment: ""), status)
        case .unauthorized:
            return NSLocalizedString("登录已过期，请重新登录", comment: "")
        case .forbidden(let message):
            return message?.isEmpty == false ? message : NSLocalizedString("没有权限执行此操作", comment: "")
        case .rateLimited:
            return NSLocalizedString("操作过于频繁，请稍后再试", comment: "")
        case .oauth(_, let description, _):
            return description?.isEmpty == false ? description : NSLocalizedString("登录失败，请重试", comment: "")
        case .decoding:
            return NSLocalizedString("服务返回的数据无法解析", comment: "")
        }
    }

    /// refresh token 失效/被撤销，必须清空本地会话。
    var isInvalidGrant: Bool {
        if case .oauth(let code, _, _) = self {
            return code == "invalid_grant"
        }
        return false
    }

    /// 是否属于「凭证问题」（应清会话），而不是网络/服务端临时故障。
    var isCredentialFailure: Bool {
        switch self {
        case .unauthorized:
            return true
        case .oauth(_, _, let status):
            return status == 400 || status == 401
        default:
            return false
        }
    }
}

/// OAuth 错误响应：`{"error":"invalid_grant","error_description":"..."}`。
struct OAuthErrorResponse: Decodable {
    let error: String
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}
