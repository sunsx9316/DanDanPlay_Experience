//
//  KeychainRefreshTokenStore.swift
//  AniXPlayer
//
//  macOS only：refresh token 只存 Keychain。
//

import Foundation
import Security

final class KeychainRefreshTokenStore: RefreshTokenStore {
    private let service: String
    private let account = "oauth.refresh_token"

    init(service: String = Bundle.main.bundleIdentifier ?? "com.anixplayer.mac.AniXPlayer") {
        self.service = service
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    func readRefreshToken() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw RefreshTokenStoreError.keychain(status: status, operation: "读取")
        }
        guard let data = item as? Data,
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty else {
            return nil
        }
        return token
    }

    func saveRefreshToken(_ token: String) throws {
        guard !token.isEmpty else {
            throw RefreshTokenStoreError.keychain(status: errSecParam, operation: "写入")
        }

        let data = Data(token.utf8)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let addStatus = SecItemAdd(baseQuery.merging(attributes) { $1 } as CFDictionary, nil)
        if addStatus == errSecDuplicateItem {
            let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw RefreshTokenStoreError.keychain(status: updateStatus, operation: "更新")
            }
            return
        }
        guard addStatus == errSecSuccess else {
            throw RefreshTokenStoreError.keychain(status: addStatus, operation: "写入")
        }
    }

    func deleteRefreshToken() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw RefreshTokenStoreError.keychain(status: status, operation: "删除")
        }
    }
}
