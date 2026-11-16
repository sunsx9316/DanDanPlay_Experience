//
//  DownloadPreferences.swift
//  AniXPlayer
//
//  macOS：下载中心设置、保存目录 bookmark 与 Transmission RPC 凭据。
//  RPC 密码优先 Keychain；Debug 构建可回退到 0600 文件（不写日志）。
//

import Foundation
import Security

// MARK: - Save directory access

enum DownloadFileAccess {

    static func makeBookmark(for url: URL) -> Data? {
        (try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )) ?? (try? url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ))
    }

    /// 解析任务保存目录。返回的 securityScopedURL 需要调用方在完成后 stopAccessing。
    static func resolveDirectory(path: String, bookmark: Data?) -> (url: URL, securityScopedURL: URL?) {
        let fallback = URL(fileURLWithPath: path, isDirectory: true)
        guard let bookmark else { return (fallback, nil) }

        var stale = false
        guard let resolved = try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else {
            return (fallback, nil)
        }

        if resolved.startAccessingSecurityScopedResource() {
            return (resolved, resolved)
        }
        return (resolved, nil)
    }
}

// MARK: - Credentials

protocol TransmissionCredentialStore {
    func readPassword() throws -> String?
    func savePassword(_ password: String?) throws
}

enum TransmissionCredentialError: LocalizedError {
    case keychain(status: OSStatus, operation: String)
    case file(operation: String, reason: String)

    var errorDescription: String? {
        switch self {
        case .keychain(let status, let operation):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
            return String(
                format: NSLocalizedString("Keychain %@失败：%@", comment: ""),
                operation,
                message
            )
        case .file(let operation, let reason):
            return String(
                format: NSLocalizedString("RPC 密码文件%@失败：%@", comment: ""),
                operation,
                reason
            )
        }
    }
}

final class KeychainTransmissionCredentialStore: TransmissionCredentialStore {
    private let service: String
    private let account = "transmission.rpc.password"

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

    func readPassword() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw TransmissionCredentialError.keychain(status: status, operation: "读取")
        }
        guard let data = item as? Data,
              let password = String(data: data, encoding: .utf8),
              !password.isEmpty else {
            return nil
        }
        return password
    }

    func savePassword(_ password: String?) throws {
        guard let password, !password.isEmpty else {
            let status = SecItemDelete(baseQuery as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw TransmissionCredentialError.keychain(status: status, operation: "删除")
            }
            return
        }

        let attributes: [String: Any] = [
            kSecValueData as String: Data(password.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let addStatus = SecItemAdd(baseQuery.merging(attributes) { $1 } as CFDictionary, nil)
        if addStatus == errSecDuplicateItem {
            let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw TransmissionCredentialError.keychain(status: updateStatus, operation: "更新")
            }
            return
        }
        guard addStatus == errSecSuccess else {
            throw TransmissionCredentialError.keychain(status: addStatus, operation: "写入")
        }
    }
}

/// 与 FileRefreshTokenStore 相同的 Debug 策略：未签名构建不弹 Keychain 授权框。
final class FileTransmissionCredentialStore: TransmissionCredentialStore {
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
    }

    func readPassword() throws -> String? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let value = try String(contentsOf: fileURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    func savePassword(_ password: String?) throws {
        guard let password, !password.isEmpty else {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            return
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

        try Data(password.utf8).write(to: fileURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )

        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = fileURL
        try? mutableURL.setResourceValues(values)
    }

    static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support", isDirectory: true)

        return base
            .appendingPathComponent("AniXPlayer", isDirectory: true)
            .appendingPathComponent("transmission.rpc.password", isDirectory: false)
    }
}

enum TransmissionCredentialStoreFactory {
    static func makeDefault(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> TransmissionCredentialStore {
        switch environment["ANIX_TRANSMISSION_CREDENTIAL_STORE"]?.lowercased() {
        case "file":
            return FileTransmissionCredentialStore()
        case "keychain":
            return KeychainTransmissionCredentialStore()
        default:
            break
        }

        #if os(macOS) && DEBUG
        return FileTransmissionCredentialStore()
        #else
        return KeychainTransmissionCredentialStore()
        #endif
    }
}

// MARK: - Preferences

final class DownloadPreferences {

    static let shared = DownloadPreferences()

    private enum Key {
        static let defaultSavePath = "download.defaultSavePath"
        static let defaultSaveBookmark = "download.defaultSaveBookmark"
        static let enableBT = "download.enableBT"
        static let rpcHost = "download.rpcHost"
        static let rpcPort = "download.rpcPort"
        static let rpcUsername = "download.rpcUsername"
        static let rpcUseHTTPS = "download.rpcUseHTTPS"
        static let sequentialDownload = "download.sequentialDownload"
        static let maxConcurrent = "download.maxConcurrent"
        static let notificationsEnabled = "download.notificationsEnabled"
        static let btOnboardingDismissed = "download.btOnboardingDismissed"
        static let downloadSpeedLimitKBps = "download.speedLimit.downloadKBps"
        static let uploadSpeedLimitKBps = "download.speedLimit.uploadKBps"
        static let seedRatioLimit = "download.seedRatioLimit"
        static let remotePathPrefix = "download.pathMapping.remotePrefix"
        static let localPathPrefix = "download.pathMapping.localPrefix"
    }

    private let defaults: UserDefaults
    private let credentialStore: TransmissionCredentialStore

    init(
        defaults: UserDefaults = .standard,
        credentialStore: TransmissionCredentialStore = TransmissionCredentialStoreFactory.makeDefault()
    ) {
        self.defaults = defaults
        self.credentialStore = credentialStore
    }

    // MARK: Directory

    static var systemDefaultDirectory: URL {
        // 新安装默认放在用户可见的 ~/Downloads/AniXPlayer。
        // App Sandbox 通过 com.apple.security.files.downloads.read-write 授予访问；
        // 已有任务使用各自持久化的 savePath，不会被迁移。
        let downloads = FileManager.default.urls(
            for: .downloadsDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Downloads", isDirectory: true)

        return downloads.appendingPathComponent("AniXPlayer", isDirectory: true)
    }

    var defaultSavePath: String {
        if let value = defaults.string(forKey: Key.defaultSavePath), !value.isEmpty {
            return value
        }
        return Self.systemDefaultDirectory.path
    }

    var defaultSaveBookmark: Data? {
        defaults.data(forKey: Key.defaultSaveBookmark)
    }

    var defaultSaveDirectoryURL: URL {
        URL(fileURLWithPath: defaultSavePath, isDirectory: true)
    }

    @discardableResult
    func ensureDefaultSaveDirectory() throws -> URL {
        let access = DownloadFileAccess.resolveDirectory(
            path: defaultSavePath,
            bookmark: defaultSaveBookmark
        )
        defer {
            access.securityScopedURL?.stopAccessingSecurityScopedResource()
        }
        try FileManager.default.createDirectory(
            at: access.url,
            withIntermediateDirectories: true
        )
        return access.url
    }

    func setDefaultSaveDirectory(_ url: URL, bookmark: Data?) {
        defaults.set(url.path, forKey: Key.defaultSavePath)
        if let bookmark {
            defaults.set(bookmark, forKey: Key.defaultSaveBookmark)
        } else {
            defaults.removeObject(forKey: Key.defaultSaveBookmark)
        }
    }

    // MARK: BT

    var enableBT: Bool {
        if defaults.object(forKey: Key.enableBT) == nil {
            return true
        }
        return defaults.bool(forKey: Key.enableBT)
    }

    var rpcHost: String {
        defaults.string(forKey: Key.rpcHost) ?? "127.0.0.1"
    }

    var rpcPort: Int {
        let value = defaults.integer(forKey: Key.rpcPort)
        return (1...65535).contains(value) ? value : 9091
    }

    var rpcUsername: String {
        defaults.string(forKey: Key.rpcUsername) ?? ""
    }

    var rpcUseHTTPS: Bool {
        defaults.bool(forKey: Key.rpcUseHTTPS)
    }

    var sequentialDownload: Bool {
        if defaults.object(forKey: Key.sequentialDownload) == nil {
            return true
        }
        return defaults.bool(forKey: Key.sequentialDownload)
    }

    var maxConcurrentDownloads: Int {
        let value = defaults.integer(forKey: Key.maxConcurrent)
        return (1...8).contains(value) ? value : 3
    }

    var notificationsEnabled: Bool {
        if defaults.object(forKey: Key.notificationsEnabled) == nil {
            return true
        }
        return defaults.bool(forKey: Key.notificationsEnabled)
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Key.notificationsEnabled)
    }

    var btOnboardingDismissed: Bool {
        defaults.bool(forKey: Key.btOnboardingDismissed)
    }

    func setBTOnboardingDismissed(_ dismissed: Bool) {
        defaults.set(dismissed, forKey: Key.btOnboardingDismissed)
    }

    // MARK: Transfer limits / remote path mapping

    /// 0 表示不限制；单位 KB/s。
    var downloadSpeedLimitKBps: Int {
        max(0, defaults.integer(forKey: Key.downloadSpeedLimitKBps))
    }

    /// 0 表示不限制；单位 KB/s。
    var uploadSpeedLimitKBps: Int {
        max(0, defaults.integer(forKey: Key.uploadSpeedLimitKBps))
    }

    /// 0 表示不启用分享率限制。
    var seedRatioLimit: Double {
        max(0, defaults.double(forKey: Key.seedRatioLimit))
    }

    var remotePathPrefix: String {
        defaults.string(forKey: Key.remotePathPrefix)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    var localPathPrefix: String {
        defaults.string(forKey: Key.localPathPrefix)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    func setTransferLimits(
        downloadKBps: Int,
        uploadKBps: Int,
        seedRatio: Double
    ) {
        defaults.set(max(0, downloadKBps), forKey: Key.downloadSpeedLimitKBps)
        defaults.set(max(0, uploadKBps), forKey: Key.uploadSpeedLimitKBps)
        defaults.set(max(0, seedRatio), forKey: Key.seedRatioLimit)
    }

    func setRemotePathMapping(remotePrefix: String, localPrefix: String) {
        defaults.set(
            remotePrefix.trimmingCharacters(in: .whitespacesAndNewlines),
            forKey: Key.remotePathPrefix
        )
        defaults.set(
            localPrefix.trimmingCharacters(in: .whitespacesAndNewlines),
            forKey: Key.localPathPrefix
        )
    }

    var transferLimits: TransmissionTransferLimits {
        TransmissionTransferLimits(
            downloadKBps: downloadSpeedLimitKBps,
            uploadKBps: uploadSpeedLimitKBps,
            seedRatio: seedRatioLimit
        )
    }

    var rpcConfiguration: TransmissionRPCConfiguration {
        TransmissionRPCConfiguration(
            host: rpcHost,
            port: rpcPort,
            useHTTPS: rpcUseHTTPS,
            username: rpcUsername,
            password: storedRPCPassword(),
            sequentialDownload: sequentialDownload
        )
    }

    func storedRPCPassword() -> String {
        (try? credentialStore.readPassword()) ?? ""
    }

    /// `password == nil` 表示保留原密码；空字符串表示清除。
    func updateRPC(
        host: String,
        port: Int,
        useHTTPS: Bool,
        username: String,
        password: String?,
        sequentialDownload: Bool,
        enableBT: Bool,
        maxConcurrentDownloads: Int
    ) throws {
        defaults.set(host.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Key.rpcHost)
        defaults.set((1...65535).contains(port) ? port : 9091, forKey: Key.rpcPort)
        defaults.set(useHTTPS, forKey: Key.rpcUseHTTPS)
        defaults.set(username.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Key.rpcUsername)
        defaults.set(sequentialDownload, forKey: Key.sequentialDownload)
        defaults.set(enableBT, forKey: Key.enableBT)
        defaults.set(min(max(maxConcurrentDownloads, 1), 8), forKey: Key.maxConcurrent)

        if let password {
            try credentialStore.savePassword(password)
        }
    }

    func clearRPCPassword() throws {
        try credentialStore.savePassword(nil)
    }
}
