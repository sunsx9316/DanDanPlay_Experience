//
//  RefreshTokenStore.swift
//  AniXPlayer
//
//  macOS only：refresh token 存储抽象。
//

import Foundation

protocol RefreshTokenStore {
    func readRefreshToken() throws -> String?
    func saveRefreshToken(_ token: String) throws
    func deleteRefreshToken() throws
}

enum RefreshTokenStoreError: LocalizedError {
    case keychain(status: OSStatus, operation: String)
    case file(operation: String, reason: String)

    var errorDescription: String? {
        switch self {
        case .keychain(let status, let operation):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
            return String(
                format: NSLocalizedString("无法安全保存登录信息（%@，%@），请检查钥匙串权限", comment: ""),
                operation,
                message
            )
        case .file(let operation, let reason):
            return String(
                format: NSLocalizedString("无法保存登录信息（%@，%@）", comment: ""),
                operation,
                reason
            )
        }
    }
}
