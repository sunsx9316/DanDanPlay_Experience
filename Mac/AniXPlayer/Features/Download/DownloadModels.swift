//
//  DownloadModels.swift
//  AniXPlayer
//
//  macOS：下载中心的数据模型、来源解析、状态机与纯逻辑。
//  本文件不依赖 AppKit，直接编入单元测试 target。
//

import CryptoKit
import Foundation
import UniformTypeIdentifiers

// MARK: - Kind / Status

enum DownloadTaskKind: String, Codable, CaseIterable {
    case http
    case torrent
    case magnet

    var displayName: String {
        switch self {
        case .http:
            return NSLocalizedString("链接", comment: "")
        case .torrent:
            return NSLocalizedString("种子", comment: "")
        case .magnet:
            return NSLocalizedString("磁力", comment: "")
        }
    }

    var isBitTorrent: Bool {
        self != .http
    }
}

enum DownloadTaskStatus: String, Codable, CaseIterable {
    case queued
    case downloading
    case paused
    case stopped
    case completed
    case failed

    var displayName: String {
        switch self {
        case .queued:
            return NSLocalizedString("等待中", comment: "")
        case .downloading:
            return NSLocalizedString("下载中", comment: "")
        case .paused:
            return NSLocalizedString("已暂停", comment: "")
        case .stopped:
            return NSLocalizedString("已停止", comment: "")
        case .completed:
            return NSLocalizedString("已完成", comment: "")
        case .failed:
            return NSLocalizedString("失败", comment: "")
        }
    }

    var isActive: Bool {
        self == .queued || self == .downloading
    }

    var isFinished: Bool {
        self == .completed || self == .failed
    }

    var canPause: Bool {
        self == .queued || self == .downloading
    }

    var canStop: Bool {
        self == .queued || self == .downloading || self == .paused
    }

    var canStart: Bool {
        switch self {
        case .paused, .stopped, .failed:
            return true
        case .queued, .downloading, .completed:
            // 已完成的任务可能对应已写入磁盘的文件；再次开始会生成第二份文件，
            // 因此必须显式删除或重新添加，绝不静默重启。
            return false
        }
    }

    /// 合法状态迁移。相同状态视为合法（用于幂等刷新）。
    func canTransition(to newStatus: DownloadTaskStatus) -> Bool {
        if self == newStatus { return true }

        switch (self, newStatus) {
        case (.queued, .downloading),
             (.queued, .paused),
             (.queued, .stopped),
             (.queued, .failed):
            return true
        case (.downloading, .queued),
             (.downloading, .paused),
             (.downloading, .stopped),
             (.downloading, .completed),
             (.downloading, .failed):
            return true
        case (.paused, .queued),
             (.paused, .downloading),
             (.paused, .stopped),
             (.paused, .completed),
             (.paused, .failed):
            return true
        case (.stopped, .queued),
             (.stopped, .downloading),
             (.stopped, .completed),
             (.stopped, .failed):
            return true
        case (.failed, .queued),
             (.failed, .downloading),
             (.failed, .stopped):
            return true
        default:
            return false
        }
    }
}

enum DownloadStateTransitionError: LocalizedError, Equatable {
    case invalid(from: DownloadTaskStatus, to: DownloadTaskStatus)

    var errorDescription: String? {
        switch self {
        case .invalid(let from, let to):
            return String(
                format: NSLocalizedString("下载任务状态不能从「%@」变为「%@」", comment: ""),
                from.displayName,
                to.displayName
            )
        }
    }
}

// MARK: - Task

struct DownloadTask: Equatable, Identifiable {
    var id: UUID
    var kind: DownloadTaskKind
    var source: String
    var title: String
    var savePath: String
    var status: DownloadTaskStatus
    var progress: Double
    var downloadedBytes: Int64
    var totalBytes: Int64
    var downloadSpeed: Int64
    var uploadSpeed: Int64
    var etaSeconds: Int?
    var errorMessage: String?
    var createdAt: Date
    var updatedAt: Date
    var engineTaskID: String?
    var filePaths: [String]
    var isStreaming: Bool
    var streamPath: String?
    /// 用户通过 NSOpenPanel 选择的保存目录的 security-scoped bookmark。
    var savePathBookmark: Data?

    init(
        id: UUID = UUID(),
        kind: DownloadTaskKind,
        source: String,
        title: String,
        savePath: String,
        status: DownloadTaskStatus = .queued,
        progress: Double = 0,
        downloadedBytes: Int64 = 0,
        totalBytes: Int64 = 0,
        downloadSpeed: Int64 = 0,
        uploadSpeed: Int64 = 0,
        etaSeconds: Int? = nil,
        errorMessage: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        engineTaskID: String? = nil,
        filePaths: [String] = [],
        isStreaming: Bool = false,
        streamPath: String? = nil,
        savePathBookmark: Data? = nil
    ) {
        self.id = id
        self.kind = kind
        self.source = source
        self.title = title
        self.savePath = savePath
        self.status = status
        self.progress = progress
        self.downloadedBytes = downloadedBytes
        self.totalBytes = totalBytes
        self.downloadSpeed = downloadSpeed
        self.uploadSpeed = uploadSpeed
        self.etaSeconds = etaSeconds
        self.errorMessage = errorMessage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.engineTaskID = engineTaskID
        self.filePaths = filePaths
        self.isStreaming = isStreaming
        self.streamPath = streamPath
        self.savePathBookmark = savePathBookmark
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? source : trimmed
    }

    var isBitTorrent: Bool {
        kind.isBitTorrent
    }

    var normalizedProgress: Double {
        min(max(progress, 0), 1)
    }

    var saveDirectoryURL: URL {
        URL(fileURLWithPath: savePath, isDirectory: true)
    }

    mutating func transition(to newStatus: DownloadTaskStatus, at date: Date = Date()) throws {
        guard status.canTransition(to: newStatus) else {
            throw DownloadStateTransitionError.invalid(from: status, to: newStatus)
        }
        status = newStatus
        updatedAt = date
        if newStatus == .completed {
            progress = 1
            downloadSpeed = 0
            uploadSpeed = 0
            etaSeconds = nil
            errorMessage = nil
        }
    }
}

// MARK: - Per-file progress

/// BT 任务的单文件状态。来自 Transmission `torrent-get` 的 `files` 字段，
/// 仅保存在内存中（重启后在下次轮询时恢复），不需要数据库迁移。
struct DownloadFileProgress: Equatable {
    /// Transmission files 数组中的索引，用于 `torrent-set`。
    var index: Int
    var path: String
    var length: Int64
    var completedBytes: Int64
    var isWanted: Bool
    /// Transmission 文件优先级：-1 低、0 普通、1 高。
    var priority: Int

    init(
        index: Int,
        path: String,
        length: Int64,
        completedBytes: Int64,
        isWanted: Bool,
        priority: Int = 0
    ) {
        self.index = index
        self.path = path
        self.length = length
        self.completedBytes = completedBytes
        self.isWanted = isWanted
        self.priority = priority
    }

    var progress: Double {
        guard length > 0 else { return 0 }
        return min(max(Double(completedBytes) / Double(length), 0), 1)
    }
}


// MARK: - Source parsing

struct DownloadSource: Equatable {
    let kind: DownloadTaskKind
    /// 规范化后的来源（磁力保留 tracker，btih 统一大写）。
    let source: String
    let suggestedTitle: String
    /// 磁力任务的信息哈希（小写，用于和 Transmission 对应）。
    let infoHash: String?
}

enum DownloadSourceError: LocalizedError, Equatable {
    case empty
    case invalidMagnet
    case unsupportedScheme(String)
    case invalidURL
    case missingTorrentFile(String)

    var errorDescription: String? {
        switch self {
        case .empty:
            return NSLocalizedString("请输入磁力链接、种子文件或下载地址", comment: "")
        case .invalidMagnet:
            return NSLocalizedString("磁力链接无效：缺少 xt=urn:btih: 信息哈希", comment: "")
        case .unsupportedScheme(let scheme):
            return String(format: NSLocalizedString("不支持的链接类型：%@", comment: ""), scheme)
        case .invalidURL:
            return NSLocalizedString("下载地址无效", comment: "")
        case .missingTorrentFile(let path):
            return String(format: NSLocalizedString("找不到种子文件：%@", comment: ""), path)
        }
    }
}

enum DownloadSourceParser {

    private static let magnetHashPattern = try! NSRegularExpression(
        pattern: #"urn:(btih|sha1):([A-Za-z0-9]+)"#,
        options: [.caseInsensitive]
    )
    private static let httpSchemePattern = try! NSRegularExpression(
        pattern: #"^https?://"#,
        options: [.caseInsensitive]
    )

    /// 解析用户输入。支持：
    /// - `magnet:?xt=urn:btih:...`
    /// - `ddplay:magnet:?xt=...`
    /// - `http(s)://.../xxx.torrent`
    /// - 本地 `.torrent` 文件路径 / file URL
    /// - 普通 HTTP/HTTPS 直链
    static func parse(_ rawValue: String) throws -> DownloadSource {
        var raw = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { throw DownloadSourceError.empty }

        // 弹弹play 自定义协议：ddplay:magnet:?xt=... 或 ddplay://magnet:?xt=...
        if raw.lowercased().hasPrefix("ddplay://magnet:") {
            raw = String(raw.dropFirst("ddplay://".count))
        } else if raw.lowercased().hasPrefix("ddplay:magnet:") {
            raw = String(raw.dropFirst("ddplay:".count))
        }

        if raw.lowercased().hasPrefix("magnet:") {
            return try parseMagnet(raw)
        }

        if let url = URL(string: raw), url.isFileURL {
            guard url.path.lowercased().hasSuffix(".torrent") else {
                throw DownloadSourceError.unsupportedScheme("file")
            }
            return try parseTorrentFile(path: url.path)
        }

        if httpSchemePattern.firstMatch(
            in: raw,
            options: [],
            range: NSRange(raw.startIndex..<raw.endIndex, in: raw)
        ) != nil {
            guard let url = URL(string: raw), let host = url.host, !host.isEmpty else {
                throw DownloadSourceError.invalidURL
            }
            if url.path.lowercased().hasSuffix(".torrent") {
                return DownloadSource(
                    kind: .torrent,
                    source: raw,
                    suggestedTitle: torrentTitle(fromFileName: url.deletingPathExtension().lastPathComponent),
                    infoHash: nil
                )
            }
            return DownloadSource(
                kind: .http,
                source: raw,
                suggestedTitle: httpTitle(for: url),
                infoHash: nil
            )
        }

        // 本地 .torrent 路径（未加 file://）
        if raw.lowercased().hasSuffix(".torrent") {
            return try parseTorrentFile(path: raw)
        }

        if let url = URL(string: raw), let scheme = url.scheme, !scheme.isEmpty {
            throw DownloadSourceError.unsupportedScheme(scheme)
        }
        throw DownloadSourceError.invalidURL
    }

    static func isTorrentFileURL(_ value: String) -> Bool {
        guard let url = URL(string: value) else { return false }
        return (url.scheme == "http" || url.scheme == "https")
            && url.path.lowercased().hasSuffix(".torrent")
    }

    /// 从磁力链接提取 btih/sha1（大写原样）。
    static func magnetInfoHash(in magnet: String) -> String? {
        let range = NSRange(magnet.startIndex..<magnet.endIndex, in: magnet)
        guard let match = magnetHashPattern.firstMatch(in: magnet, options: [], range: range),
              let hashRange = Range(match.range(at: 2), in: magnet) else {
            return nil
        }
        return String(magnet[hashRange])
    }

    // MARK: Private

    private static func parseMagnet(_ raw: String) throws -> DownloadSource {
        let fullRange = NSRange(raw.startIndex..<raw.endIndex, in: raw)
        guard let match = magnetHashPattern.firstMatch(in: raw, options: [], range: fullRange),
              let schemeRange = Range(match.range(at: 1), in: raw),
              let hashRange = Range(match.range(at: 2), in: raw) else {
            throw DownloadSourceError.invalidMagnet
        }

        let hashScheme = String(raw[schemeRange]).lowercased()
        let rawHash = String(raw[hashRange])
        guard isValidHash(rawHash, scheme: hashScheme) else {
            throw DownloadSourceError.invalidMagnet
        }

        // 保留 dn/tr 等参数，仅规范 btih 的大小写与 magnet:? 前缀。
        var normalized = raw
        if !normalized.dropFirst("magnet:".count).hasPrefix("?") {
            let remainder = normalized.dropFirst("magnet:".count)
            normalized = "magnet:?" + remainder
        }
        if hashScheme == "btih" {
            let normalizedRange = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
            if let normalizedMatch = magnetHashPattern.firstMatch(in: normalized, options: [], range: normalizedRange),
               let normalizedHashRange = Range(normalizedMatch.range(at: 2), in: normalized) {
                normalized.replaceSubrange(normalizedHashRange, with: rawHash.uppercased())
            }
        }

        let title = magnetDisplayName(normalized, hash: rawHash)
        return DownloadSource(
            kind: .magnet,
            source: normalized,
            suggestedTitle: title,
            infoHash: normalizedInfoHash(rawHash) ?? rawHash.lowercased()
        )
    }

    private static func isValidHash(_ hash: String, scheme: String) -> Bool {
        switch scheme {
        case "btih":
            // 40 位十六进制，或 32 位 Base32。
            if hash.count == 40 {
                return hash.unicodeScalars.allSatisfy { CharacterSet(charactersIn: "0123456789abcdefABCDEF").contains($0) }
            }
            if hash.count == 32 {
                return hash.unicodeScalars.allSatisfy {
                    CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567abcdefghijklmnopqrstuvwxyz").contains($0)
                }
            }
            return false
        case "sha1":
            return hash.count == 40
        default:
            return false
        }
    }

    private static func magnetDisplayName(_ magnet: String, hash: String) -> String {
        if let components = URLComponents(string: magnet),
           let name = components.queryItems?.first(where: { $0.name.lowercased() == "dn" })?.value,
           !name.isEmpty {
            return name.replacingOccurrences(of: "+", with: " ")
        }
        let short = hash.count > 8 ? String(hash.prefix(8)).uppercased() : hash.uppercased()
        return String(format: NSLocalizedString("磁力任务 %@", comment: ""), short)
    }

    private static func parseTorrentFile(path: String) throws -> DownloadSource {
        let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
        guard FileManager.default.fileExists(atPath: standardized) else {
            throw DownloadSourceError.missingTorrentFile(standardized)
        }
        let title = torrentTitle(fromFileName: ((standardized as NSString).lastPathComponent as NSString).deletingPathExtension)
        let infoHash = BitTorrentMetainfo.infoHash(atPath: standardized)
        return DownloadSource(
            kind: .torrent,
            source: standardized,
            suggestedTitle: title,
            infoHash: infoHash?.lowercased()
        )
    }

    private static func torrentTitle(fromFileName name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? NSLocalizedString("种子任务", comment: "") : trimmed
    }

    private static func httpTitle(for url: URL) -> String {
        let last = url.pathComponents.last ?? ""
        let decoded = last.removingPercentEncoding ?? last
        if !decoded.isEmpty, decoded != "/" {
            return decoded
        }
        if let host = url.host, !host.isEmpty {
            return host
        }
        return NSLocalizedString("下载任务", comment: "")
    }
}

// MARK: - Torrent metadata

/// 极简 bencode 扫描器：只用于提取顶层 `info` 字典的原始字节并计算 SHA-1 信息哈希。
/// 不解析文件名、不下载种子，仅用于添加任务时去重。
enum BitTorrentMetainfo {

    static func infoHash(atPath path: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }
        return infoHash(in: data)
    }

    static func infoHash(in data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        let bytes = [UInt8](data)
        guard bytes[0] == UInt8(ascii: "d") else { return nil }

        var index = 1
        while index < bytes.count, bytes[index] != UInt8(ascii: "e") {
            guard let (key, keyEnd) = parseByteString(bytes, at: index) else { return nil }
            let valueStart = keyEnd
            guard let valueEnd = skipValue(bytes, at: valueStart, depth: 0) else { return nil }
            if key == Array("info".utf8) {
                let infoBytes = Data(bytes[valueStart..<valueEnd])
                let digest = Insecure.SHA1.hash(data: infoBytes)
                return digest.map { String(format: "%02x", $0) }.joined()
            }
            index = valueEnd
        }
        return nil
    }

    private static func parseByteString(_ bytes: [UInt8], at start: Int) -> ([UInt8], Int)? {
        var index = start
        var length = 0
        var digits = 0
        while index < bytes.count, bytes[index] >= UInt8(ascii: "0"), bytes[index] <= UInt8(ascii: "9") {
            length = length * 10 + Int(bytes[index] - UInt8(ascii: "0"))
            digits += 1
            index += 1
            if digits > 9 || length > bytes.count { return nil }
        }
        guard digits > 0, index < bytes.count, bytes[index] == UInt8(ascii: ":") else {
            return nil
        }
        index += 1
        guard index + length <= bytes.count else { return nil }
        return (Array(bytes[index..<(index + length)]), index + length)
    }

    private static func skipValue(_ bytes: [UInt8], at start: Int, depth: Int) -> Int? {
        guard depth < 64, start < bytes.count else { return nil }

        switch bytes[start] {
        case UInt8(ascii: "i"):
            var index = start + 1
            while index < bytes.count, bytes[index] != UInt8(ascii: "e") {
                index += 1
            }
            return index < bytes.count ? index + 1 : nil

        case UInt8(ascii: "l"):
            var index = start + 1
            while index < bytes.count, bytes[index] != UInt8(ascii: "e") {
                guard let next = skipValue(bytes, at: index, depth: depth + 1) else { return nil }
                index = next
            }
            return index < bytes.count ? index + 1 : nil

        case UInt8(ascii: "d"):
            var index = start + 1
            while index < bytes.count, bytes[index] != UInt8(ascii: "e") {
                guard let (_, keyEnd) = parseByteString(bytes, at: index),
                      let next = skipValue(bytes, at: keyEnd, depth: depth + 1) else {
                    return nil
                }
                index = next
            }
            return index < bytes.count ? index + 1 : nil

        default:
            return parseByteString(bytes, at: start)?.1
        }
    }
}

// MARK: - Deduplication

extension DownloadSourceParser {

    /// 任务去重键：磁力/种子优先使用 info hash；HTTP 与种子 URL 使用规范化来源。
    static func deduplicationKey(for source: DownloadSource) -> String {
        if let hash = normalizedInfoHash(source.infoHash) {
            return "btih:" + hash
        }
        switch source.kind {
        case .magnet:
            return "magnet:" + source.source
        case .http:
            return "url:" + source.source
        case .torrent:
            if source.source.lowercased().hasPrefix("http://")
                || source.source.lowercased().hasPrefix("https://") {
                return "url:" + source.source
            }
            return "torrent:" + URL(fileURLWithPath: source.source).standardizedFileURL.path
        }
    }

    /// 已有任务的去重键。BT 任务在引擎接管后 `engineTaskID` 即 info hash。
    static func deduplicationKey(for task: DownloadTask) -> String? {
        if let hash = normalizedInfoHash(magnetInfoHash(in: task.source))
            ?? normalizedInfoHash(task.engineTaskID) {
            return "btih:" + hash
        }
        switch task.kind {
        case .magnet:
            return "magnet:" + task.source
        case .http:
            return "url:" + task.source
        case .torrent:
            if task.source.lowercased().hasPrefix("http://")
                || task.source.lowercased().hasPrefix("https://") {
                return "url:" + task.source
            }
            if let hash = BitTorrentMetainfo.infoHash(atPath: task.source) {
                return "btih:" + hash.lowercased()
            }
            return "torrent:" + URL(fileURLWithPath: task.source).standardizedFileURL.path
        }
    }

    static func normalizedInfoHash(_ value: String?) -> String? {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        if raw.count == 40,
           raw.unicodeScalars.allSatisfy({
               CharacterSet(charactersIn: "0123456789abcdefABCDEF").contains($0)
           }) {
            return raw.lowercased()
        }
        if raw.count == 32 {
            return base32InfoHashToHex(raw)
        }
        return nil
    }

    /// Magnet 允许 btih 使用 32 位 Base32；统一转成 40 位十六进制用于去重。
    private static func base32InfoHashToHex(_ value: String) -> String? {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        var lookup: [Character: UInt32] = [:]
        for (index, character) in alphabet.enumerated() {
            lookup[character] = UInt32(index)
        }

        var buffer: UInt32 = 0
        var bitCount = 0
        var bytes: [UInt8] = []
        for character in value.uppercased() {
            guard let digit = lookup[character] else { return nil }
            buffer = (buffer << 5) | digit
            bitCount += 5
            if bitCount >= 8 {
                bitCount -= 8
                bytes.append(UInt8((buffer >> UInt32(bitCount)) & 0xFF))
            }
        }
        guard bytes.count == 20 else { return nil }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Remote path mapping

/// 远程 Transmission 的文件路径映射：remotePrefix → localPrefix。
/// 空前缀表示不映射，保持本地 Transmission 行为不变。纯逻辑，便于单测。
enum DownloadPathMapping {

    static func map(
        _ path: String,
        remotePrefix: String,
        localPrefix: String
    ) -> String {
        let remote = normalizedPrefix(remotePrefix)
        let local = normalizedPrefix(localPrefix)
        guard !remote.isEmpty, !local.isEmpty else { return path }

        let standardizedPath = (path as NSString).standardizingPath
        let standardizedRemote = (remote as NSString).standardizingPath
        guard !standardizedRemote.isEmpty else { return path }

        let suffix: String
        if standardizedRemote == "/" {
            guard standardizedPath.hasPrefix("/") else { return path }
            suffix = standardizedPath
        } else if standardizedPath == standardizedRemote {
            suffix = ""
        } else if standardizedPath.hasPrefix(standardizedRemote + "/") {
            suffix = String(standardizedPath.dropFirst(standardizedRemote.count))
        } else {
            return path
        }

        let expandedLocal = (local as NSString).expandingTildeInPath
        let candidate = expandedLocal + suffix
        return (candidate as NSString).standardizingPath
    }

    static func map(
        paths: [String],
        remotePrefix: String,
        localPrefix: String
    ) -> [String] {
        paths.map { map($0, remotePrefix: remotePrefix, localPrefix: localPrefix) }
    }

    private static func normalizedPrefix(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        var normalized = (trimmed as NSString).standardizingPath
        while normalized.count > 1, normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        return normalized
    }
}

// MARK: - Formatting

enum DownloadFormatting {

    static func byteCount(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: max(0, bytes), countStyle: .file)
    }

    /// 速度 0 显示为 “—”，与 Windows 下载中心一致。
    static func speed(_ bytesPerSecond: Int64) -> String {
        guard bytesPerSecond > 0 else { return "—" }
        return byteCount(bytesPerSecond) + "/s"
    }

    static func eta(_ seconds: Int?) -> String {
        guard let seconds, seconds > 0, seconds < 7 * 24 * 3600 else { return "—" }
        if seconds < 60 {
            return String(format: NSLocalizedString("%d 秒", comment: ""), seconds)
        }
        if seconds < 3600 {
            return String(
                format: NSLocalizedString("%d 分 %d 秒", comment: ""),
                seconds / 60,
                seconds % 60
            )
        }
        return String(
            format: NSLocalizedString("%d 小时 %d 分", comment: ""),
            seconds / 3600,
            (seconds % 3600) / 60
        )
    }

    static func percent(_ progress: Double) -> String {
        String(format: "%.1f%%", min(max(progress, 0), 1) * 100)
    }

    static func bytesProgress(downloaded: Int64, total: Int64) -> String {
        guard total > 0 else {
            return downloaded > 0 ? byteCount(downloaded) : "—"
        }
        return "\(byteCount(downloaded)) / \(byteCount(total))"
    }

    static func taskCount(_ count: Int) -> String {
        String(format: NSLocalizedString("%d 个任务", comment: ""), count)
    }
}

// MARK: - Speed meter

/// 基于滑动窗口的下载速度计算，纯逻辑、可在测试中注入时间。
struct DownloadSpeedMeter {
    var window: TimeInterval
    private var samples: [(date: Date, total: Int64)] = []

    init(window: TimeInterval = 3) {
        self.window = window
    }

    mutating func record(totalBytes: Int64, at date: Date = Date()) -> Int64 {
        samples.append((date, max(0, totalBytes)))
        samples.removeAll { date.timeIntervalSince($0.date) > window }

        guard samples.count >= 2,
              let first = samples.first,
              let last = samples.last else {
            return 0
        }
        let interval = last.date.timeIntervalSince(first.date)
        guard interval >= 0.2 else { return 0 }
        let delta = last.total - first.total
        guard delta > 0 else { return 0 }
        return Int64(Double(delta) / interval)
    }

    mutating func reset() {
        samples.removeAll()
    }
}

// MARK: - File naming

enum DownloadFileName {

    private static let invalidCharacters = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        .union(.newlines)
        .union(.controlCharacters)

    static func sanitize(_ raw: String) -> String {
        let replaced = raw
            .components(separatedBy: invalidCharacters)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutLeadingDots = replaced.drop { $0 == "." }
        var result = String(withoutLeadingDots)
        if result.isEmpty { result = "download" }
        if result.count > 180 {
            result = String(result.prefix(180))
        }
        return result
    }

    static func fileName(from url: URL) -> String? {
        let last = url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent
        let sanitized = sanitize(last)
        return sanitized.isEmpty ? nil : sanitized
    }

    static func fileName(fromContentDisposition header: String?) -> String? {
        guard let header, !header.isEmpty else { return nil }

        // RFC 5987: filename*=UTF-8''...
        if let range = header.range(of: "filename*=", options: .caseInsensitive) {
            let value = header[range.upperBound...]
            let parts = value.split(separator: "'", maxSplits: 2, omittingEmptySubsequences: false)
            if parts.count == 3 {
                let encoded = String(parts[2]).trimmingCharacters(in: CharacterSet(charactersIn: "\"; "))
                if let decoded = encoded.removingPercentEncoding, !decoded.isEmpty {
                    return sanitize(decoded)
                }
            }
        }

        if let range = header.range(of: "filename=", options: .caseInsensitive) {
            let value = header[range.upperBound...]
            let trimmed = value
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'; "))
            let end = trimmed.firstIndex(of: ";") ?? trimmed.endIndex
            let name = String(trimmed[..<end]).trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
            if !name.isEmpty {
                return sanitize(name)
            }
        }
        return nil
    }

    static func uniqueURL(
        in directory: URL,
        preferredName: String,
        fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) -> URL {
        let sanitized = sanitize(preferredName)
        let nsName = sanitized as NSString
        let base = nsName.deletingPathExtension
        let ext = nsName.pathExtension
        var candidate = directory.appendingPathComponent(sanitized)
        var index = 2

        while fileExists(candidate.path) {
            let name: String
            if ext.isEmpty {
                name = "\(base) (\(index))"
            } else {
                name = "\(base) (\(index)).\(ext)"
            }
            candidate = directory.appendingPathComponent(name)
            index += 1
        }
        return candidate
    }
}

// MARK: - Playback rules

enum DownloadFileRules {

    static let videoExtensions: Set<String> = [
        "mkv", "mp4", "avi", "mov", "rmvb", "webm", "flv", "ts", "m2ts", "wmv", "m4v",
    ]

    /// BT 边下边播的最小文件大小：20 MB。
    static let minimumStreamingBytes: Int64 = 20 * 1024 * 1024

    /// 没有可识别扩展名时的兜底大小。大于该值且不是文本/图片等已知类型时，认为可能是视频。
    static let fallbackPlayableBytes: Int64 = 10 * 1024 * 1024

    private static let nonPlayableExtensions: Set<String> = [
        "srt", "ass", "ssa", "sub", "idx", "nfo", "txt", "pdf", "json", "xml",
        "html", "htm", "torrent", "jpg", "jpeg", "png", "gif", "webp", "bmp", "heic",
    ]

    static func isVideoFile(path: String) -> Bool {
        videoExtensions.contains((path as NSString).pathExtension.lowercased())
    }

    /// 已完成文件是否值得尝试播放：扩展名、UTType 或大小兜底。
    static func isPlayableCandidate(path: String, size: Int64?) -> Bool {
        if isVideoFile(path: path) { return true }

        let ext = (path as NSString).pathExtension.lowercased()
        if nonPlayableExtensions.contains(ext) { return false }
        if !ext.isEmpty, let type = UTType(filenameExtension: ext) {
            if type.conforms(to: .movie)
                || type.conforms(to: .video)
                || type.conforms(to: .audiovisualContent) {
                return true
            }
            if type.conforms(to: .text)
                || type.conforms(to: .image)
                || type.conforms(to: .audio) {
                return false
            }
            return (size ?? 0) >= fallbackPlayableBytes
        }

        // 无扩展名或系统不认识的扩展名：只按大小兜底。
        return (size ?? 0) >= fallbackPlayableBytes
    }

    static func existingFileSize(at path: String) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let type = attributes[.type] as? FileAttributeType,
              type == .typeRegular,
              let size = attributes[.size] as? NSNumber else {
            return nil
        }
        return size.int64Value
    }

    static func preferredFile(
        in paths: [String],
        sizeAtPath: (String) -> Int64?
    ) -> String? {
        paths
            .filter { isVideoFile(path: $0) }
            .compactMap { path -> (String, Int64)? in
                guard let size = sizeAtPath(path) else { return nil }
                return (path, size)
            }
            .max { $0.1 < $1.1 }?
            .0
    }

    /// 完成任务的播放列表：所有存在的视频文件，按自然文件名/集数顺序排列（从第一集开始）。
    static func playablePaths(
        for task: DownloadTask,
        sizeAtPath: (String) -> Int64? = { existingFileSize(at: $0) }
    ) -> [String] {
        guard task.status == .completed else { return [] }
        var seen = Set<String>()
        return task.filePaths
            .filter { seen.insert($0).inserted }
            .compactMap { path -> (String, Int64)? in
                guard let size = sizeAtPath(path), size > 0 else { return nil }
                return (path, size)
            }
            .filter { isPlayableCandidate(path: $0.0, size: $0.1) }
            .map { $0.0 }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// 完成任务取第一个可播放文件；未完成 BT 任务仅在文件 >20MB 时返回路径。
    static func playablePath(
        for task: DownloadTask,
        sizeAtPath: (String) -> Int64? = { existingFileSize(at: $0) }
    ) -> String? {
        if task.status == .completed {
            return playablePaths(for: task, sizeAtPath: sizeAtPath).first
        }
        guard task.isBitTorrent, task.status != .failed else { return nil }

        let candidates = task.streamPath.map { [$0] + task.filePaths } ?? task.filePaths
        var seen = Set<String>()
        let unique = candidates.filter { seen.insert($0).inserted }
        for path in unique where isVideoFile(path: path) {
            if let size = sizeAtPath(path), size >= minimumStreamingBytes {
                return path
            }
        }
        return nil
    }

    /// 已完成任务的文件是否全部消失（被移动/删除）。
    static func hasMissingFiles(
        _ task: DownloadTask,
        fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) -> Bool {
        guard task.status == .completed, !task.filePaths.isEmpty else { return false }
        return task.filePaths.allSatisfy { !fileExists($0) }
    }
}

// MARK: - Query

enum DownloadFilter: String, CaseIterable {
    case all
    case active
    case completed
    case failed

    var displayName: String {
        switch self {
        case .all:
            return NSLocalizedString("全部", comment: "")
        case .active:
            return NSLocalizedString("进行中", comment: "")
        case .completed:
            return NSLocalizedString("已完成", comment: "")
        case .failed:
            return NSLocalizedString("失败", comment: "")
        }
    }

    func matches(_ task: DownloadTask) -> Bool {
        switch self {
        case .all:
            return true
        case .active:
            return task.status == .queued
                || task.status == .downloading
                || task.status == .paused
                || task.status == .stopped
        case .completed:
            return task.status == .completed
        case .failed:
            return task.status == .failed
        }
    }
}

enum DownloadSort: String, CaseIterable {
    case createdAt
    case title
    case status
    case progress
    case speed
    case size

    var displayName: String {
        switch self {
        case .createdAt:
            return NSLocalizedString("按添加时间", comment: "")
        case .title:
            return NSLocalizedString("按标题", comment: "")
        case .status:
            return NSLocalizedString("按状态", comment: "")
        case .progress:
            return NSLocalizedString("按进度", comment: "")
        case .speed:
            return NSLocalizedString("按速度", comment: "")
        case .size:
            return NSLocalizedString("按大小", comment: "")
        }
    }
}

struct DownloadQuery: Equatable {
    var searchText: String = ""
    var filter: DownloadFilter = .all
    var sort: DownloadSort = .createdAt

    var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum DownloadQueryLogic {

    static func matches(_ task: DownloadTask, query: DownloadQuery) -> Bool {
        guard query.filter.matches(task) else { return false }

        let keyword = query.trimmedSearchText
        guard !keyword.isEmpty else { return true }

        let candidates = [task.displayTitle, task.source, task.savePath]
        return candidates.contains {
            $0.range(
                of: keyword,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: nil,
                locale: .current
            ) != nil
        }
    }

    static func sorted(_ tasks: [DownloadTask], by sort: DownloadSort) -> [DownloadTask] {
        tasks.sorted { lhs, rhs in
            switch sort {
            case .createdAt:
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt > rhs.createdAt
                }
            case .title:
                let result = lhs.displayTitle.localizedStandardCompare(rhs.displayTitle)
                if result != .orderedSame { return result == .orderedAscending }
            case .status:
                let lhsRank = statusRank(lhs.status)
                let rhsRank = statusRank(rhs.status)
                if lhsRank != rhsRank { return lhsRank < rhsRank }
            case .progress:
                if lhs.normalizedProgress != rhs.normalizedProgress {
                    return lhs.normalizedProgress > rhs.normalizedProgress
                }
            case .speed:
                if lhs.downloadSpeed != rhs.downloadSpeed {
                    return lhs.downloadSpeed > rhs.downloadSpeed
                }
            case .size:
                if lhs.totalBytes != rhs.totalBytes {
                    return lhs.totalBytes > rhs.totalBytes
                }
            }
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    static func apply(_ tasks: [DownloadTask], query: DownloadQuery) -> [DownloadTask] {
        sorted(tasks.filter { matches($0, query: query) }, by: query.sort)
    }

    private static func statusRank(_ status: DownloadTaskStatus) -> Int {
        switch status {
        case .downloading: return 0
        case .queued: return 1
        case .paused: return 2
        case .stopped: return 3
        case .failed: return 4
        case .completed: return 5
        }
    }
}
