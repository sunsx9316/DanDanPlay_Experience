//
//  FileRefreshTokenStore.swift
//  AniXPlayer
//
//  macOS：refresh token 的文件存储（开发/未签名构建用）。
//
//  仅保存 refresh token；access token 始终只在内存中。
//  文件位于 App 沙盒的 Application Support/AniXPlayer/，权限 0600，
//  并标记为不参与备份。安全等级低于 Keychain，正式发布默认仍用 Keychain。
//

import Foundation

final class FileRefreshTokenStore: RefreshTokenStore {
    private let fileURL: URL

    /// - Parameter fileURL: 测试可注入临时文件；默认使用 App Support 下的固定路径。
    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
    }

    func readRefreshToken() throws -> String? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        let token = try String(contentsOf: fileURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return token.isEmpty ? nil : token
    }

    func saveRefreshToken(_ token: String) throws {
        guard !token.isEmpty else {
            throw RefreshTokenStoreError.file(operation: "写入", reason: "token 为空")
        }

        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: directory.path
        )

        let data = Data(token.utf8)
        try data.write(to: fileURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )

        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = fileURL
        try? mutableURL.setResourceValues(values)
    }

    func deleteRefreshToken() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }

    static func defaultFileURL() -> URL {
        let base: URL
        if let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first {
            base = applicationSupport
        } else {
            base = URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        }

        return base
            .appendingPathComponent("AniXPlayer", isDirectory: true)
            .appendingPathComponent("oauth.refresh_token", isDirectory: false)
    }
}

/// 选择持久化 refresh token 的存储。
///
/// 优先级：
/// 1. 环境变量 `ANIX_TOKEN_STORE=file|keychain`
/// 2. macOS Debug 默认 file（未签名/临时签名不会弹钥匙串授权）
/// 3. 其他情况 Keychain
enum RefreshTokenStoreFactory {
    static func makeDefault(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> RefreshTokenStore {
        switch environment["ANIX_TOKEN_STORE"]?.lowercased() {
        case "file":
            return FileRefreshTokenStore()
        case "keychain":
            return KeychainRefreshTokenStore()
        default:
            break
        }

        #if os(macOS) && DEBUG
        return FileRefreshTokenStore()
        #else
        return KeychainRefreshTokenStore()
        #endif
    }
}
